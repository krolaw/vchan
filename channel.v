module channels

/*
Channels needs the following sugar:
c <- x       :  c.push(x)  
x := <- c    :  x := c.pull()  
for i in c { :  for i := c.pull() ; i != none ; i = c.pull() {
*/

// makeChan provides Go like channels. size -1 for uncapped channels
pub fn make_chan(size int) &Channel {
    if size == 0 {
        return make_zero_chan()
    }
    return make_buf_chan(size)
}

interface Channel {
    // push_select returns true if it can immediately able to push to a channel.
    // Otherwise f will be called when the channel can be pushed. f returns none
    // if select no longer wants to push to the channel.
    push_select(value int, f fn() ?int) bool

    // pull_select returns an int if immediately available from the channel.
    // Otherwise f will be called with int (none if chan closes) when available.
    // f returns false if select no longer wants value from channel.
    pull_select(f fn(?int) bool) ?int

    pub:
        // len() returns current length of channel
        len() int
        // cap() returns capacity of channel, -ve means unbounded
        cap() int
        // push blocks until value can be placed on channel
        //  push panics if channel is closed.
        push(value int)
        // pull blocks until value is returned, returns none if channel closes
        pull() ?int
        // close closes the channel
        close()
}





