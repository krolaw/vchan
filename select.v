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
    s := &Select{}
	s.blocker.wait{}
}

struct Select {
    mut:
		ctrl &sync.Mutex // Manager Mutex
		blocker &sync.Waiter = &sync.Waiter(0) // Blocker
		finished bool
		task fn() // what to do once route decided
}

pub fn (s Select) default(do fn()) {
	s.ctrl.m_lock()
	defer { s.ctrl.unlock() }
	if s.finished {
		return
	}
	s.finished = true
	do()
}

pub fn (s Select) block() {
	s.blocker.wait()
	s.task()
}

// push is syntactic sugar: case chan <- value: do...
pub fn (s Select) push(mut chan Channel, value int, do fn()) {
	s.ctrl.m_lock() // Prevent other channels completing while setting up this one
	defer { s.ctrl.unlock() }
	if s.finished {
		return
	}
	if chan.push_select(value,fn() ?int {
		s.ctrl.m_lock()
		defer { s.ctrl.unlock() }
		if s.finished {
			return none
		}
		s.finished = true
		s.task = do // set, not run as this isn't select's thread
		s.blocker.stop()
	}) {
		s.finished = true
		s.task = do
		s.blocker.stop()
	}
}

//pull_select(fn(?int) bool) ?int
pub fn (s Select) pull(mut chan Channel, do fn(?int)) {
	s.ctrl.m_lock() // Prevent other channels completing while setting up this one
	defer { s.ctrl.unlock() }
	if s.finished {
		return
	}
	value := chan.pull_select(fn(s ?int) bool {
		s.ctrl.m_lock()
		defer { s.ctrl.unlock() }
		if s.finished {
			return false
		}
		s.finished = true
		s.task = fn() { do(s) } // set, not run as this isn't select's thread
		s.blocker.stop()
		return true
	}) or {
		return
	}
	s.finished = true
	s.task = fn() { do(s) }
	s.blocker.stop()
}


