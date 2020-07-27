module channels

import sync

fn test_chan() {
    stress_chan(0,10,10,10000)
    stress_chan(10,10,10,10000)
}

fn stress_chan(size int, senders int, receivers int, testsPerSender int) {

    mut c := make_chan(size)

    go fn(mut c Channel) {
        mut wg := sync.new_waitgroup()
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
    }(mut c)

    mut c2 := make_chan(size)
    for i := 0 ; i < receivers ; i++ {
        go fn() {
            for {
                r := c.pull() or {
                    break
                }
                c2.push(r)
            }
        }()
    }

    mut arr := []int{} // how do I init a zero length int array?
    for {
        r := c2.pull() or {
            break
        }
        for i := 0 ; i < arr.len ; i++ {
            assert arr[i] != r
        }
        arr << r
    }

    assert arr.len == testsPerSender * senders
}

