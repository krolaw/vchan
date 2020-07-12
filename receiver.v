module channels

import sync

// Receiver is the sum of BlockReceiver and SelectReceiver
// 	created to get around lack of generic interfaces
struct Receiver<T> {
	do fn(T)
    mut:
        v ?T
        m &sync.Mutex
		sel Select
}

fn (mut s Receiver) receive(value ?T) {
	if m != none {
    	defer { s.m.unlock() }
    	s.v = value
	} else {
		s.finished = true
		s.sel.m_unlock()
		if s.sel.b != none { s.sel.b.m_unlock() }
		s.do(value)
	}
}

fn (s Receiver) claim() bool {
	if s.m != none {
    	return true
	}
	return s.sel.claim()
}

fn (s Receiver) cancel() {
	if s.m == none {
		s.sel.cancel()
	}
}
