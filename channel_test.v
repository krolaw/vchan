module channels

import sync

fn test_chan() {
    stress_chan(0,10,10,10000)
    stress_chan(10,10,10,10000)
}

fn stress_chan(size int, senders int, receivers int, testsPerSender int) {

    c := make_chan<int>(size)

    go fn(c Channel) {
        mut wg := &sync.WaitGroup{}
        wg.add(senders)
        for i := 0 ; i < senders ; i++ {
            go fn(i int) {
                for j := 0 ; j < testsPerSender ; j++ {
                    c.push(i*testsPerSender+j)
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
                r := c.pull(i)
                if r.finished {
                    break
                }
                c2.push(r.value)
            }
        }()
    }

    mut arr := [] // how do I init a zero length int array?
    for {
        r := c2.pull()
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

