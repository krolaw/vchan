module channels

/*
Channels needs the following sugar:
c <- x       :  c.push(x)  
x := <- c    :  x := c.pull()  
for i in c { :  for i := c.pull() ; i != none ; i = c.pull() {
*/

import sync

// makeChan provides Go like channels. size -1 for uncapped channels
pub fn make_chan<T>(size int) &Channel<T> {
    return &Channel{size: size}
}


struct Channel<T> {
    size int
    mut:
        ctrl sync.Mutex
        receivers []Receiver
        senders []Sender
        buffer []T
        closed bool
}

// push places a value to the end of Channel, blocking until a free slot is available.
// Syntactic sugar for: c <- value
pub fn (c mut Channel<T>) push(value T) {
    var m Mutex
    m.lock()
    c.register_sender(blockingSender{value,&m})
    m.lock()
}

// pull takes a value from the front of the Channel, blocking until a value is available
// Syntactic sugar for: <- c
pub fn (c mut Channel) pull<T>() ?T {
    var m Mutex
    receiver := blockingReceiver{m:m}
    m.lock()
    c.reg(receiver)
    m.lock()
    return receiver.v
}

// close flags the channel as closed, pushing to a closed channel will panic
pub fn (c mut Channel) close() {
    c.ctrl.lock()
    if c.closed {
        panic("Channel already closed")
    }
    c.closed = true
    for r in receivers {
        if r.claim_receive() {
            r.receive(none)
        }
    }
    c.ctrl.unlock()
}

pub fn (c mut Channel) len() int {
    c.ctrl.lock()
    defer c.ctrl.unlock()
    return c.buffer.len()
}

pub fn (c Channel) cap() int {
    return c.size
}

fn (c mut Channel<T>) register_sender(s ClaimSender) {
    c.ctrl.lock()
    defer c.ctrl.unlock()

    if !s.claim() {
        return // Select sender disappearered while waiting for channel lock, so exit
    }

    if c.closed {
        panic('Cannot send to closed Channel')
    }

    for c.receivers.len > 0 {
        r := c.receivers[0]
        c.receivers.removeAt(0)
        if !r.claim() {
            continue
        }
        s.send(r)
        return
    }

    if c.size < 0 || c.size > c.buffer.len {
        s.send(c) // send calls c.receive with value
        return
    }
    senders.add(s)
}

fn (c mut Channel<T>) receive(value T) {
    c.buffer.add(value)
}

fn (c mut Channel<T>) register_receiver(r ClaimReceiver) bool {
    c.ctrl.lock()
    defer c.ctrl.unlock()

    if !r.claim() {
        return true // Select receiver disappearered while waiting for channel lock, so exit
    }

    if c.buffer.len > 0 {
        r.receive(c.buffer.removeAt(0).value)
        return true
    }

    if c.closed {
        return false
    }

    for c.senders.len > 0 {
        s := c.senders[0]
        c.senders.removeAt(0)
        if !s.claim() {
            continue
        }
        s.send(r)
        return
    }
    receivers.add(r)
    return true
}





