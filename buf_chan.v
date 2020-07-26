module channels

import sync

fn make_buf_chan(size int) &BufChannel {
    c := &BufChannel{
        size: size,
    }
	// Ready waiters to wait on next call
    c.rec.wait()
	c.send.wait()
	c.select_pull_block.wait()
	c.select_push_block.wait()
    return c
}

struct BufChannel {
    size int
    mut:
        ctrl &sync.Mutex = &sync.Mutex(0) // Manager Mutex
        rec  &sync.Waiter = &sync.Waiter(0) // Receiver Mutex
        send &sync.Waiter = &sync.Waiter(0) // Sender Mutex

		waiting_select_pull bool
		waiting_select_push bool
		select_pull_block &sync.Waiter = &sync.Waiter(0) // Blocks until producer ready to go
    	select_push_block &sync.Waiter = &sync.Waiter(0) // Blocks until consumer ready to go

        buffer []int // buffered channel data
        closed bool
        count int // Tracks waiting producers (+ve) or consumers (-ve)
}

pub fn (mut c BufChannel) len() int {
    c.ctrl.m_lock()
    defer { c.ctrl.m_unlock() }
    return c.buffer.len()
}

pub fn (c BufChannel) cap() int {
    return c.size
}

pub fn (mut c BufChannel) close() {
	c.ctrl.m_lock()
    defer { c.ctrl.m_unlock() }
	if c.closed {
		panic("Cannot close an already closed channel")
	}
	if c.count > 0 {
		panic("Cannot push to a closed channel")
	}
	c.closed = true
}

fn (mut c BufChannel) push_select(value int, f fn() ?int) bool {
	c.ctrl.m_lock()
    defer { c.ctrl.m_unlock() }

	for {
		if c.len < c.size {
			c.buffer.add(value)
			if c.len == 1 {
				c.rec_block.stop()
			}
			return true
		}

		if count >= 0 {
			c.count++
			go fn() {
				for {
					c.send_block.wait()
					c.ctrl.m_lock()
					if c.buffer.len < c.size {
						val := f() or {
							c.unblock_push()
						}
						c.buffer.add(val)
						count++
						c.unblock_pull()
						c.ctrl.m_unlock()
						break
					}
					c.ctrl.m_unlock()
				}
			}
			return false
		}
		// At this point the buffer is full, but we have waiting consumers that have not yet
		// removed from the buffer. It's a rare corner case. We'll divert back to this thread
		// once the consumer has taken a value off. Wait for them and then loop.
		c.waiting_select_push = true
		c.ctrl.unlock()
		c.select_push_block.wait()
		c.ctrl.m_lock()
	}
}


fn (mut c BufChannel) pull_select(f fn(_ ?int) bool) ?int {
	c.ctrl.m_lock()
    defer { c.ctrl.m_unlock() }

	for {
		if c.buffer.len > 0 {
			value := c.buffer[0]
			c.buffer.removeAt(0)
			return value
		}
		
		if count <= 0 {
			go fn() {
				for {
					c.rec_block.wait()
					c.ctrl.m_lock()
					defer { c.ctrl.m_unlock() }

					if c.buffer.len > 0 {
						if !f(c.buffer[0]) {
							// Select no longer interested, free another receive to collect
							unblock_pull()
							return
						}
						c.buffer.removeAt(0)
						if c.count > 0 {
							count--
							unblock_push()
						}
						break
					}
				}
			}
			return none
		}
		// At this point the buffer is empty, but we have waiting producers that have not yet
		// pushed into the buffer. It's a rare corner case. We'll divert back to this thread
		// once the producer has dropped a value off.
		c.waiting_select_pull = true
		c.ctrl.unlock()
		c.ctrl.select_pull_block.wait()
		c.ctrl.m_lock()
	}
}

fn (mut c BufChannel) unblock_pull() {
	if c.waiting_select_pull {
		c.waiting_select_pull = false
		c.select_pull_block.stop()
	} else {
		c.rec.stop()
	}
}

fn (mut c BufChannel) unblock_push() {
	if c.waiting_select_push {
		c.waiting_select_push = false
		c.select_push_block.stop()
	} else {
		c.send_block.stop()
	}
}



// push places a value to the end of BufChannel, blocking until a free slot is available.
// Syntactic sugar for: c <- value
fn (mut c BufChannel) push(value int) {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    for c.buffer.len == c.size {
        c.count++
        c.ctrl.unlock()
        c.send.wait() // Block here
        c.ctrl.m_lock()
    }

	if c.closed {
        panic("Cannot push to a closed channel")
    }

	c.buffer.add(value)

    if c.count < 0 { // If there are waiting receivers unblock
		count++
        unblock_pull()
    }
}

// pull blocks until a value is received from the channel
fn (mut c BufChannel) pull() ?int {
    c.ctrl.m_lock()
    defer { c.ctrl.unlock() }

    for c.buffer.len == 0 {
        if c.closed {
            s(none)
            return
        }
        c.count--
        c.ctrl.unlock()
        c.rec.wait() // Block until
        c.ctrl.m_lock()
    }

    c.buffer.removeAt(0)

    if c.count > 0 {
		count--
		unblock_push()
    }
}
