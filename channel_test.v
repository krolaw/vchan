module channels

fn test_chan() {
    stress_chan(0,10,10,10000)
    stress_chan(10,10,10,10000)
}

fn stress_chan(size int, senders int, receivers int, testsPerSender int) {

    c := make_chan(size)

    go fn(c) {
        mut wg := &WaitGroup{}
        wg.add(senders)
        for i := 0 ; i < senders ; i++ {
            go fn(i) {
                for j := 0 ; j < testsPerSender ; j++ {
                    c.send(i*testsPerSender+j)
                }
                wg.done()
            }(i)
        }
        wg.wait()
        c.close()
    }(c)

    c2 := makeChan(size)
    for i := 0 ; i < receivers ; i++ {
        go fn() {
            for {
                r := c.receive()
                if r.finished {
                    break
                }
                c2.send(r.value)
            }
        }
    }

    mut arr := [] // how do I init a zero length int array?
    for {
        r := c2.receive()
        if r.finished {
            break
        }
        for i := 0 ; i < arr.len ; i++ {
            assert arr[i] != r.value
        }
        arr << r.value
    }

    assert arr.len == testsPerSender * senders
}

