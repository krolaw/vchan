module channels

import sync

interface ClaimSender<T> {
	claim() bool
	send(Receiver<T>)
	cancel()
}

interface Sender<T> {
	send(Receiver<T>)
}

interface ClaimReceiver<T> {
	claim() bool
	receive(T)
	cancel()
}

interface Receiver<T> {
	receive(T)
}


struct BlockingSender<T> {
    value T
    mut:
        m &sync.Mutex 
}

fn (s mut BlockingSender) send() T {
    defer s.m.unlock()
    return s.value
}

fn (s BlockingSender) claim() bool {
    return true
}

fn (s BlockingSender) cancel() {}


struct BlockingReceiver<T> {
    mut:
        v ?T
        m &sync.Mutex 
}

fn (s mut BlockingReceiver) receive(value ?T) {
    defer s.m.unlock()
    s.v = value
}

fn (s BlockingReceiver) claim() bool {
    return true
}

fn (s BlockingReceiver) cancel() {}
