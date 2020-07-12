module channels

import sync

interface ClaimSender{ //<T> {
	claim() bool
	send(Receiver) //<T>)
	cancel()
}

interface Sender{ //<T> {
	send(Receiver) //<T>)
}
/*
interface ClaimReceiver<T> {
	claim() bool
	receive(T)
	cancel()
}

interface Receiver<T> {
	receive(T)
}*/


struct BlockingSender<T> {
    value T
    mut:
        m &sync.Mutex 
}

fn (mut s BlockingSender) send(r Receiver) {
    defer { s.m.unlock() }
    return r.send(s.value)
}

fn (s BlockingSender) claim() bool {
    return true
}

fn (s BlockingSender) cancel() {}

// BlockingReceiver currently unused
struct BlockingReceiver<T> {
    mut:
        v ?T
        m &sync.Mutex 
}

fn (mut s BlockingReceiver) receive(value ?T) {
    defer { s.m.unlock() }
    s.v = value
}

fn (s BlockingReceiver) claim() bool {
    return true
}

fn (s BlockingReceiver) cancel() {}
