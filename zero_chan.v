module channels

import sync

fn make_zero_chan() &ZeroChannel {
    c := &BufChannel{
		produce: fn() ?int { panic("Non-existent produce bug in library") }
		consume: fn(v ?int) bool { panic("Non-existent consume bug in library") }
	}
	// Ready waiters to wait on next call
    c.rec_block.wait()
	c.send_block.wait()
	c.rec_fin_block.wait()
	c.send_fin_block.wait()
    return c
}

// With zero sized channels, if you want to consume, there has to be a waiting producer in the produce field.
// If there isn't a waiting producer, you populate your consume fn in the consume field.
struct ZeroChannel {
	ctrl &sync.Mutex = &sync.Mutex(0) // Manager Mutex
	
    rec_block &sync.Waiter = &sync.Waiter(0) // Blocks consumers until producer arrives
    send_block &sync.Waiter = &sync.Waiter(0) // Blocks producers until consumer arrives

	rec_fin_block &sync.Waiter = &sync.Waiter(0) // Blocks until producer ready to go
    send_fin_block &sync.Waiter = &sync.Waiter(0) // Blocks until consumre ready to go

	produce fn() ?int
	consume fn(?int) bool

	count int // Tracks waiting senders +ve / receivers -ve
    closed bool
}

fn (c ZeroChannel) len() { return 0 }
fn (c ZeroChannel) cap() { return 0 }

fn (c ZeroChannel) close() {
	c.ctrl.m_lock()
	defer { c.ctrl.unlock() }

	if c.closed {
		panic("Cannot close channel that is already closed")
	}

	if c.count > 0 {
		// Closing when there is waiting producers
		panic("Cannot push to a closed channel")
	}

	for c.count < 0 {
		c.rec_block.stop()
		c.send_fin_block.wait()
		c.consume(none)
	}
}

fn (c ZeroChannel) pull_select(s fn(?int) bool) ?int {
	c.ctrl.m_lock()
	defer { c.ctrl.unlock() }

	if c.closed {
		return none
	}

	for c.count > 0 {
		c.send_block.stop() // release a producer
		c.rec_fin_block.wait() // wait for producer to be provided
		c.count--
		if c.provide() {
			return c.value // value available right now
		}
	}

	go fn() {
		c.rec_block.wait()
		c.consume = s
		c.send_fin_block.stop()
	}

	return none // pull queued
}

fn (c ZeroChannel) push_select(value int, s fn() ?int) bool {
	c.ctrl.m_lock()
	defer { c.ctrl.unlock() }

	if c.closed {
		panic("Cannot push to a closed channel")
	}

	for c.count < 0 {
		c.rec_block.stop() // release a consumer
		c.send_fin_block.wait() // wait for consumer to be provided
		c.count++
		if c.consume(value) {
			return true // value 
		}
	}

	go fn() {
		c.send_block.wait()
		c.producer = s
		c.send_fin_block.stop()
	}

	return false 
}

fn (c ZeroChannel) push(value int) {

	c.ctrl.m_lock()
	if c.closed {
		panic("Cannot push to a closed channel")
	}
	for c.count < 0 {
		c.rec_block.stop() // release a consumer
		c.send_fin_block.wait() // wait for consumer to be provided
		c.count++
		if c.consume(value) {
			c.ctrl.unlock()
			return true // value 
		}
	}
	c.ctrl.unlock()

	c.send_block.wait() // wait for consumer
	m := &sync.Waiter(0)
	m.wait()
	c.value = value
	c.producer = fn() bool {
		m.stop()
		return true
	}
	m.rec_fin_block.stop() // tell consumer producer is ready
	m.wait()
}

fn (c ZeroChannel) pull() ?int {

	c.ctrl.m_lock()
	if c.closed {
		c.ctrl.unlock()
		return none
	}
	for c.count > 0 {
		c.send_block.stop() // release a producer
		c.rec_fin_block.wait() // wait for producer to be provided
		c.count--
		value := c.producer() or {
			continue
		}
		c.ctrl.unlock()
		return value
	}
	c.ctrl.unlock()

	c.rec_block.wait() // wait for producer
	m := &sync.Waiter(0)
	m.wait()
	mut value ?int
	c.consumer = fn(v ?int) bool {
		value = v
		m.stop()
	}
	m.send_fin_block.stop() // tell producer consumer is ready
	m.wait()
	return value
}
