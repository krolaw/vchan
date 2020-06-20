module channels

import sync

/*
select {                : s := channels.Select{}
   case x := <-c : ...  : s.pull(c, fn(x) { ... })
   case c <- x : ...    : s.push(c, x, fn() { ... })
   default: ...         : s.default(fn() { ... })
}                       : s.block() // only if default is not used
*/


struct Select {
    mut:
        m sync.Mutex
		b &sync.Mutex
        finished bool
		count int
}

// push is syntactic sugar: case chan <- value: do...
pub fn (s Select) push<T>(chan Channel<T>, value T, do fn()) {
	chan.register_sender(SelectSender{value,do,&s})
}

// pull is syntactic sugar: case x := <- chan: do(x)
pub fn (s Select) pull<T>(chan Channel<T>, do fn(T)) {
	if chan.registerReceiver(SelectReceiver{do,&s}) {
		s.count++
	}
}

// default is syntactic sugar: default: do...
// default OR block (not both) must be called at the end of the select operation
pub fn (s Select) default(do fn()) {
	m.lock()
	if s.finished {
		m.unlock()
		return
	} else {
		s.finished = true
		m.unlock()
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
		s.m.lock()
		defer s.m.unlock()
		if s.finished {
			return
		}
		s.b = sync.Mutex{}
		s.b.lock()
		s.b.lock()
	}
}

fn (s mut Select) claim() bool {
	s.m.lock()
	if s.finished {
		s.m.unlock()
		return false
	}
	return true
}

fn (s mut Select) cancel() { // When receiver bails
	s.m.unlock()
}

struct SelectSender<T> {
	value T
	do fn()
	mut:
		&Select
}

fn (s mut SelectSender) send(r Receiver) {
	r.receive(s.value)
	s.finished = true
	s.unlock()
	if(s.b != none) s.b.unlock()
	s.do()
}

struct SelectReceiver<T> {
	do fn(?T)
	mut: 
		Select
}

fn (s SelectReceiver) receive(value ?T) ?T{
	s.finished = true
	s.unlock()
	if(s.b != none) s.b.unlock()
	s.do(value)
}




