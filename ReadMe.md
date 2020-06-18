# V Channels

This is a first attempt at implementation of Go like channels and selects for V.

Pros
- Uses no platform dependent code.
- Requires only Mutexes.

Cons
- Completely untested, can't compile, awaiting generic structs, likely has bugs/design issues.
- It currently is non-performant due to its internal array handling.
- Uses locks, I hear there are non-locking implementations.
- Poorly researched, the focus was getting something functional NOW, with expectations of replacement LATER.

I'm making this public to help development of V, either to provide code, or provide knowledge that something else needs to be found. 