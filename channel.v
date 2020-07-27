module channels

import sync

/*
Channels needs the following sugar:
c <- x       :  c.push(x)  
x := <- c    :  x := c.pull()  
for i in c { :  for i := c.pull() ; i != none ; i = c.pull() {
*/

type Producer fn() ?int
type Consumer fn(_ ?int) bool

// makeChan provides Go like channels. size -1 for uncapped channels
pub fn make_chan(cap int) &Channel {
    return &Channel{
        ctrl: sync.new_mutex(),
        size : cap,
        producers : []Producer{},
        consumers : []Consumer{},
        buffer : []int{ cap: cap },
        closed : false,
    }
}

struct Channel {
    size int

    mut:
        ctrl &sync.Mutex = &sync.Mutex(0) // Manager Mutex
        producers []Producer
        consumers []Consumer
        buffer []int // buffered channel data
        closed bool
}

type NoneInt ?int

// pull blocks until value is returned, returns none if channel closes
pub fn (mut c Channel) pull() ?int {
    return c.pull_else(fn() ?int{
        mut w := &sync.Waiter(0)
        w.wait()
        mut value := NoneInt(0) // mut value := ?int(none)
        c.consumers << fn(v ?int) bool {
            value = v
            w.stop()
            return true
        }
        w.wait()
        return value
    })
}

// pull_select returns a value if immediately available from the channel.
// Otherwise f will be called with a value (none if chan closes) when available.
// f returns false if select no longer wants value from channel.
fn (mut c Channel) pull_select(f Consumer) ?int {
    return c.pull_else(fn() ?int {
        c.consumers << f
        return none
    })
}

fn (mut c Channel) pull_else(do_else fn() ?int) ?int {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    if c.closed {
        return none
    }

    if c.buffer.len > 0 {
        value := c.buffer[0]
        c.buffer = c.buffer[1..] // .removeAt(0)
        return value
    }

    for c.producers.len > 0 {
        p := c.producers[0]
        c.producers = c.producers[1..] //.removeAt(0)
        value := p() or {
            continue
        }
        return value
    }

    return do_else()
}

// len() returns current length of channel
pub fn (mut c Channel) len() int {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }
    return c.buffer.len
}

// cap() returns capacity of channel, -ve means unbounded
pub fn (c Channel) cap() int {
    return c.size
}

// close closes the channel
pub fn (mut c Channel) close() {
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
pub fn (mut c Channel) push(value int) {
    c.push_else(value,fn() {
        mut w := &sync.Waiter(0)
        w.wait()
        c.producers << fn() ?int {
            w.stop()
            return value
        }
        w.wait()
    })
}

// push_select returns true if it can immediately able to push to a channel.
// Otherwise f will be called when the channel can be pushed. f returns none
// if select no longer wants to push to the channel.
fn (mut c Channel) push_select(value int, f Producer) bool {
    return c.push_else(value, fn() {
        c.producers << f
    })
}

fn (mut c Channel) push_else(value int, do_else fn()) bool {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    if c.closed {
        panic("Cannot push to a closed channel")
    }

    for c.consumers.len > 0 {
        r := c.consumers[0]
        c.consumers = c.consumers[1..] // .removeAt(0)
        if r(value) {
            return true
        }
    }

    if c.buffer.len < c.size || c.size < 0 {
        c.buffer << value
        return true
    }

    do_else()
    return false
}







