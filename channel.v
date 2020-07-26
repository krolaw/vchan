module channels

import sync

/*
Channels needs the following sugar:
c <- x       :  c.push(x)  
x := <- c    :  x := c.pull()  
for i in c { :  for i := c.pull() ; i != none ; i = c.pull() {
*/

// makeChan provides Go like channels. size -1 for uncapped channels
pub fn make_chan(size int) &Channel {
    return &Channel{
        size : size
    }
}

struct Channel {
    size int

    mut:
        ctrl &sync.Mutex = &sync.Mutex(0) // Manager Mutex
        producers []fn() ?int
        consumers []fn(?int) bool
        buffer []int // buffered channel data
        closed bool
}

// pull blocks until value is returned, returns none if channel closes
pub fn pull() ?int {
    return pull_else(fn() ?int{
        w := &sync.Waiter(0)
        w.wait()
        var value ?int
        c.consumers.add(fn(v ?int) bool) {
            w.stop()
            value = v
            return true
        })
        w.wait()
        return value
    })
}

// pull_select returns a value if immediately available from the channel.
// Otherwise f will be called with a value (none if chan closes) when available.
// f returns false if select no longer wants value from channel.
fn (mut c Channel) pull_select(f fn(?int) bool) ?int {
    return pull_else(fn() ?int {
        c.consumers.add(f)
        return none
    })
}

fn (mut c Channel) pull_else(do_else fn()) ?int {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    if c.closed {
        return none
    }

    if buffer.len > 0 {
        value := buffer[0]
        buffer.removeAt(0)
        return value
    }

    for c.producers.len > 0 {
        p := c.producers[0]
        c.producers.removeAt(0)
        value := p(value) or {
            continue
        }
        return value
    }

    return do_else()
}

// len() returns current length of channel
pub fn (c Channel) len() int {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }
    return c.buffer.len
}

// cap() returns capacity of channel, -ve means unbounded
pub fn (c Channel) cap() int {
    return c.size
}

// close closes the channel
pub fn close() {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }
    if c.closed {
        panic("Cannot close an already closed channel")
    }
    c.closed = true
    if c.producers.len > 0 {
        panic("Cannot push to a closed channel")
    }
    for r in c.consumers {
        r(none)
    }
}

// push blocks until value can be placed on channel
//  push panics if channel is closed.
pub fn (c Channel) push(value int) {
    push_else(value,fn() {
        w := &sync.Waiter(0)
        w.wait()
        c.producers.add(fn() ?int {
            w.stop()
            return value
        })
        w.wait()
    })
}

// push_select returns true if it can immediately able to push to a channel.
// Otherwise f will be called when the channel can be pushed. f returns none
// if select no longer wants to push to the channel.
fn (mut c Channel) push_select(value int, f fn() ?int) bool {
    return push_else(value, fn() {
        c.producers.add(f)
    })
}

fn (c Channel) push_else(value int, do_else fn()) bool {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    if c.closed {
        panic("Cannot push to a closed channel")
    }

    for c.consumers.len > 0 {
        r := c.consumers[0]
        c.consumers.removeAt(0)
        if r(value) {
            return true
        }
    }

    if buffer.len < size || size < 0 {
        c.buffer.add(value)
        return true
    }

    do_else()
    return false
}







