module channels

import sync

/*
select {                : s := make_select()
   case x := <-c : ...  : s.pull(c, fn(x) { ... })
   case c <- x : ...    : s.push(c, x, fn() { ... })
   default: ...         : s.default(fn() { ... })
}                       : s.block() // only if default is not used
*/

pub fn make_select() &Select {
    return &Select{m:sync.new_mutex(),b:sync.new_mutex()}
}


struct Select {
    mut:
        m &sync.Mutex
		b &sync.Mutex
        finished bool
		count int
}

// push is syntactic sugar: case chan <- value: do...
pub fn (s Select) push<T>(chan Channel<T>, value T, do fn()) {
	chan.register_sender(SelectSender<T>{value,do,&s})
}

// pull is syntactic sugar: case x := <- chan: do(x)
pub fn (s Select) pull<T>(chan Channel<T>, do fn(T)) {
	sr := SelectReceiver<T>{do,&s} // var created due to compiler bug?
	if chan.register_receiver(sr) {
		s.count++
	}
}

// default is syntactic sugar: default: do...
// default OR block (not both) must be called at the end of the select operation
pub fn (s Select) default(do fn()) {
	m.m_lock()
	if s.finished {
		m.m_unlock()
		return
	} else {
		s.finished = true
		m.m_unlock()
		if d != none {
			d()
		}
	}
}

// block is syntactic sugar for the end of the select, signalling that 
// the select should block until one channel operation is chosen
// default OR block (not both) must be called at the end of the select operation 
pub fn (s Select) block() {
	if s.count > 0 {
		s.m.m_lock()
		defer { s.m.m_unlock() }
		if s.finished {
			return
		}
		s.b = sync.Mutex{}
		s.b.m_lock()
		s.b.m_lock()
	}
}

fn (mut s Select) claim() bool {
	s.m.m_lock()
	if s.finished {
		s.m.m_unlock()
		return false
	}
	return true
}

fn (mut s Select) cancel() { // When receiver bails
	s.m.m_unlock()
}

struct SelectSender<T> {
	value T
	do fn()
	mut:
		sel Select
}

fn (mut s SelectSender) send(r Receiver) {
	r.receive(s.value)
	s.sel.finished = true
	s.sel.m_unlock()
	if s.sel.b != none { s.sel.b.m_unlock() }
	s.do()
}

struct SelectReceiver<T> {
	do fn(T)
	mut: 
		sel Select
}

fn (s SelectReceiver) receive(value ?T) ?T{
	s.finished = true
	s.sel.m_unlock()
	if s.sel.b != none { s.sel.b.m_unlock() }
	s.do(value)
}




