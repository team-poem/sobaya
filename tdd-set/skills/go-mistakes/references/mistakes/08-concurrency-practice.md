# Concurrency: Practice

Source: [100go.co](https://100go.co/#concurrency-practice)

## Propagating an inappropriate context (#61)

**One line:** Understanding the conditions when a context can be canceled should matter when propagating it: for example, an HTTP handler canceling the context when the response has been sent.

In many situations, it is recommended to propagate Go contexts. However, context propagation can sometimes lead to subtle bugs, preventing subfunctions from being correctly executed.

Let’s consider the following example. We expose an HTTP handler that performs some tasks and returns a response. But just before returning the response, we also want to send it to a Kafka topic. We don’t want to penalize the HTTP consumer latency-wise, so we want the publish action to be handled asynchronously within a new goroutine. We assume that we have at our disposal a `publish` function that accepts a context so the action of publishing a message can be interrupted if the context is canceled, for example. Here is a possible implementation:

```go
func handler(w http.ResponseWriter, r *http.Request) {
    response, err := doSomeTask(r.Context(), r)
    if err != nil {
        http.Error(w, err.Error(), http.StatusInternalServerError)
    return
    }
    go func() {
        err := publish(r.Context(), response)
        // Do something with err
    }()
    writeResponse(response)
}
```

What’s wrong with this piece of code? We have to know that the context attached to an HTTP request can cancel in different conditions:

* When the client’s connection closes
* In the case of an HTTP/2 request, when the request is canceled
* When the response has been written back to the client

In the first two cases, we probably handle things correctly. For example, if we get a response from doSomeTask but the client has closed the connection, it’s probably OK to call publish with a context already canceled so the message isn’t published. But what about the last case?

When the response has been written to the client, the context associated with the request will be canceled. Therefore, we are facing a race condition:

* If the response is written after the Kafka publication, we both return a response and publish a message successfully
* However, if the response is written before or during the Kafka publication, the message shouldn’t be published.

In the latter case, calling publish will return an error because we returned the HTTP response quickly.

**Note:**

From Go 1.21, there is a way to create a new context without cancel. [`context.WithoutCancel`](https://pkg.go.dev/context#WithoutCancel) returns a copy of parent that is not canceled when parent is canceled.

In summary, propagating a context should be done cautiously.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/61-inappropriate-context/main.go)

Upstream: https://100go.co/#propagating-an-inappropriate-context-61

## Starting a goroutine without knowing when to stop it (#62)

**One line:** Avoiding leaks means being mindful that whenever a goroutine is started, you should have a plan to stop it eventually.

Goroutines are easy and cheap to start—so easy and cheap that we may not necessarily have a plan for when to stop a new goroutine, which can lead to leaks. Not knowing when to stop a goroutine is a design issue and a common concurrency mistake in Go.

Let’s discuss a concrete example. We will design an application that needs to watch some external configuration (for example, using a database connection). Here’s a first implementation:

```go
func main() {
    newWatcher()
    // Run the application
}

type watcher struct { /* Some resources */ }

func newWatcher() {
    w := watcher{}
    go w.watch() // Creates a goroutine that watches some external configuration
}
```

The problem with this code is that when the main goroutine exits (perhaps because of an OS signal or because it has a finite workload), the application is stopped. Hence, the resources created by watcher aren’t closed gracefully. How can we prevent this from happening?

One option could be to pass to newWatcher a context that will be canceled when main returns:

```go
func main() {
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    newWatcher(ctx)
    // Run the application
}

func newWatcher(ctx context.Context) {
    w := watcher{}
    go w.watch(ctx)
}
```

We propagate the context created to the watch method. When the context is canceled, the watcher struct should close its resources. However, can we guarantee that watch will have time to do so? Absolutely not—and that’s a design flaw.

 The problem is that we used signaling to convey that a goroutine had to be stopped. We didn’t block the parent goroutine until the resources had been closed.  Let’s make sure we do:

```go
func main() {
    w := newWatcher()
    defer w.close()
    // Run the application
}

func newWatcher() watcher {
    w := watcher{}
    go w.watch()
    return w
}

func (w watcher) close() {
    // Close the resources
}
```

Instead of signaling `watcher` that it’s time to close its resources, we now call this `close` method, using `defer` to guarantee that the resources are closed before the application exits.

In summary, let’s be mindful that a goroutine is a resource like any other that must eventually be closed to free memory or other resources. Starting a goroutine without knowing when to stop it is a design issue. Whenever a goroutine is started, we should have a clear plan about when it will stop. Last but not least, if a goroutine creates resources and its lifetime is bound to the lifetime of the application, it’s probably safer to wait for this goroutine to complete before exiting the application. This way, we can ensure that the resources can be freed.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/62-starting-goroutine/)

Upstream: https://100go.co/#starting-a-goroutine-without-knowing-when-to-stop-it-62

## Not being careful with goroutines and loop variables (#63)

**Warning:**

This mistake isn't relevant anymore from Go 1.22 ([details](https://go.dev/blog/loopvar-preview)).

Upstream: https://100go.co/#warning-not-being-careful-with-goroutines-and-loop-variables-63

## Expecting a deterministic behavior using select and channels (#64)

**One line:** Understanding that `select` with multiple channels chooses the case randomly if multiple options are possible prevents making wrong assumptions that can lead to subtle concurrency bugs.

One common mistake made by Go developers while working with channels is to make wrong assumptions about how select behaves with multiple channels.

For example, let's consider the following case (`disconnectCh` is a unbuffered channel):

```go
go func() {
  for i := 0; i < 10; i++ {
      messageCh <- i
    }
    disconnectCh <- struct{}{}
}()

for {
    select {
    case v := <-messageCh:
        fmt.Println(v)
    case <-disconnectCh:
        fmt.Println("disconnection, return")
        return
    }
}
```

If we run this example multiple times, the result will be random:

```
0
1
2
disconnection, return

0
disconnection, return
```

Instead of consuming the 10 messages, we only received a few of them. What’s the reason? It lies in the specification of the select statement with multiple channels (https:// go.dev/ref/spec):

**Quote:**

If one or more of the communications can proceed, a single one that can proceed is chosen via a uniform pseudo-random selection.

Unlike a switch statement, where the first case with a match wins, the select statement selects randomly if multiple options are possible.

This behavior might look odd at first, but there’s a good reason for it: to prevent possible starvation. Suppose the first possible communication chosen is based on the source order. In that case, we may fall into a situation where, for example, we only receive from one channel because of a fast sender. To prevent this, the language designers decided to use a random selection.

When using `select` with multiple channels, we must remember that if multiple options are possible, the first case in the source order does not automatically win. Instead, Go selects randomly, so there’s no guarantee about which option will be chosen. To overcome this behavior, in the case of a single producer goroutine, we can use either unbuffered channels or a single channel.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/64-select-behavior/main.go)

Upstream: https://100go.co/#expecting-a-deterministic-behavior-using-select-and-channels-64

## Not using notification channels (#65)

**One line:** Send notifications using a `chan struct{}` type.

Channels are a mechanism for communicating across goroutines via signaling. A signal can be either with or without data.

Let’s look at a concrete example. We will create a channel that will notify us whenever a certain disconnection occurs. One idea is to handle it as a `chan bool`:

```go
disconnectCh := make(chan bool)
```

Now, let’s say we interact with an API that provides us with such a channel. Because it’s a channel of Booleans, we can receive either `true` or `false` messages. It’s probably clear what `true` conveys. But what does `false` mean? Does it mean we haven’t been disconnected? And in this case, how frequently will we receive such a signal? Does it mean we have reconnected? Should we even expect to receive `false`? Perhaps we should only expect to receive `true` messages.

If that’s the case, meaning we don’t need a specific value to convey some information, we need a channel _without_ data. The idiomatic way to handle it is a channel of empty structs: `chan struct{}`.

Upstream: https://100go.co/#not-using-notification-channels-65

## Not using nil channels (#66)

**One line:** Using nil channels should be part of your concurrency toolset because it allows you to _remove_ cases from `select` statements, for example.

What should this code do?

```go
var ch chan int
<-ch
```

`ch` is a `chan int` type. The zero value of a channel being nil, `ch` is `nil`. The goroutine won’t panic; however, it will block forever.

The principle is the same if we send a message to a nil channel. This goroutine blocks forever:

```go
var ch chan int
ch <- 0
```

Then what’s the purpose of Go allowing messages to be received from or sent to a nil channel? For example, we can use nil channels to implement an idiomatic way to merge two channels:

```go hl_lines="5 9 15"
func merge(ch1, ch2 <-chan int) <-chan int {
    ch := make(chan int, 1)

    go func() {
        for ch1 != nil || ch2 != nil { // Continue if at least one channel isn’t nil
            select {
            case v, open := <-ch1:
                if !open {
                    ch1 = nil // Assign ch1 to a nil channel once closed
                    break
                }
                ch <- v
            case v, open := <-ch2:
                if !open {
                    ch2 = nil // Assigns ch2 to a nil channel once closed
                    break
                }
                ch <- v
            }
        }
        close(ch)
    }()

    return ch
}
```

This elegant solution relies on nil channels to somehow _remove_ one case from the `select` statement.

Let’s keep this idea in mind: nil channels are useful in some conditions and should be part of the Go developer’s toolset when dealing with concurrent code.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/66-nil-channels/main.go)

Upstream: https://100go.co/#not-using-nil-channels-66

## Being puzzled about channel size (#67)

**One line:** Carefully decide on the right channel type to use, given a problem. Only unbuffered channels provide strong synchronization guarantees. For buffered channels, you should have a good reason to specify a channel size other than one.

An unbuffered channel is a channel without any capacity. It can be created by either omitting the size or providing a 0 size:

```go
ch1 := make(chan int)
ch2 := make(chan int, 0)
```

With an unbuffered channel (sometimes called a synchronous channel), the sender will block until the receiver receives data from the channel.

Conversely, a buffered channel has a capacity, and it must be created with a size greater than or equal to 1:

```go
ch3 := make(chan int, 1)
```

With a buffered channel, a sender can send messages while the channel isn’t full. Once the channel is full, it will block until a receiver goroutine receives a message:

```go
ch3 := make(chan int, 1)
ch3 <-1 // Non-blocking
ch3 <-2 // Blocking
```

The first send isn’t blocking, whereas the second one is, as the channel is full at this stage.

What's the main difference between unbuffered and buffered channels:

* An unbuffered channel enables synchronization. We have the guarantee that two goroutines will be in a known state: one receiving and another sending a message.
* A buffered channel doesn’t provide any strong synchronization. Indeed, a producer goroutine can send a message and then continue its execution if the channel isn’t full. The only guarantee is that a goroutine won’t receive a message before it is sent. But this is only a guarantee because of causality (you don’t drink your coffee before you prepare it).

If we need a buffered channel, what size should we provide?

The default value we should use for buffered channels is its minimum: 1. So, we may approach the problem from this standpoint: is there any good reason not to use a value of 1? Here’s a list of possible cases where we should use another size:

* While using a worker pooling-like pattern, meaning spinning a fixed number of goroutines that need to send data to a shared channel. In that case, we can tie the channel size to the number of goroutines created.
* When using channels for rate-limiting problems. For example, if we need to enforce resource utilization by bounding the number of requests, we should set up the channel size according to the limit.

If we are outside of these cases, using a different channel size should be done cautiously. Let’s bear in mind that deciding about an accurate queue size isn’t an easy problem:

**Martin Thompson:**

Queues are typically always close to full or close to empty due to the differences in pace between consumers and producers. They very rarely operate in a balanced middle ground where the rate of production and consumption is evenly matched.

Upstream: https://100go.co/#being-puzzled-about-channel-size-67

## Forgetting about possible side effects with string formatting (#68)

**One line:** Being aware that string formatting may lead to calling existing functions means watching out for possible deadlocks and other data races.

It’s pretty easy to forget the potential side effects of string formatting while working in a concurrent application.

#### [etcd](https://github.com/etcd-io/etcd) data race

[github.com/etcd-io/etcd/pull/7816](https://github.com/etcd-io/etcd/pull/7816) shows an example of an issue where a map's key was formatted based on a mutable values from a context.

#### Deadlock

Can you see what the problem is in this code with a `Customer` struct exposing an `UpdateAge` method and implementing the `fmt.Stringer` interface?

```go
type Customer struct {
    mutex sync.RWMutex // Uses a sync.RWMutex to protect concurrent accesses
    id    string
    age   int
}

func (c *Customer) UpdateAge(age int) error {
    c.mutex.Lock() // Locks and defers unlock as we update Customer
    defer c.mutex.Unlock()

    if age < 0 { // Returns an error if age is negative
        return fmt.Errorf("age should be positive for customer %v", c)
    }

    c.age = age
    return nil
}

func (c *Customer) String() string {
    c.mutex.RLock() // Locks and defers unlock as we read Customer
    defer c.mutex.RUnlock()
    return fmt.Sprintf("id %s, age %d", c.id, c.age)
}
```

The problem here may not be straightforward. If the provided age is negative, we return an error. Because the error is formatted, using the `%s` directive on the receiver, it will call the `String` method to format `Customer`. But because `UpdateAge` already acquires the mutex lock, the `String` method won’t be able to acquire it. Hence, this leads to a deadlock situation. If all goroutines are also asleep, it leads to a panic.

One possible solution is to restrict the scope of the mutex lock:

```go hl_lines="2 3 4"
func (c *Customer) UpdateAge(age int) error {
    if age < 0 {
        return fmt.Errorf("age should be positive for customer %v", c)
    }

    c.mutex.Lock()
    defer c.mutex.Unlock()

    c.age = age
    return nil
}
```

Yet, such an approach isn't always possible. In these conditions, we have to be extremely careful with string formatting.

Another approach is to access the `id` field directly:

```go hl_lines="6"
func (c *Customer) UpdateAge(age int) error {
    c.mutex.Lock()
    defer c.mutex.Unlock()

    if age < 0 {
        return fmt.Errorf("age should be positive for customer id %s", c.id)
    }

    c.age = age
    return nil
}
```

In concurrent applications, we should remain cautious about the possible side effects of string formatting.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/68-string-formatting/main.go)

Upstream: https://100go.co/#forgetting-about-possible-side-effects-with-string-formatting-68

## Creating data races with append (#69)

**One line:** Calling `append` isn’t always data-race-free; hence, it shouldn’t be used concurrently on a shared slice.

Should adding an element to a slice using `append` is data-race-free? Spoiler: it depends.

Do you believe this example has a data race? 

```go
s := make([]int, 1)

go func() { // In a new goroutine, appends a new element on s
    s1 := append(s, 1)
    fmt.Println(s1)
}()

go func() { // Same
    s2 := append(s, 1)
    fmt.Println(s2)
}()
```

The answer is no.

In this example, we create a slice with `make([]int, 1)`. The code creates a one-length, one-capacity slice. Thus, because the slice is full, using append in each goroutine returns a slice backed by a new array. It doesn’t mutate the existing array; hence, it doesn’t lead to a data race.

Now, let’s run the same example with a slight change in how we initialize `s`. Instead of creating a slice with a length of 1, we create it with a length of 0 but a capacity of 1. How about this new example? Does it contain a data race?

```go hl_lines="1"
s := make([]int, 0, 1)

go func() { 
    s1 := append(s, 1)
    fmt.Println(s1)
}()

go func() {
    s2 := append(s, 1)
    fmt.Println(s2)
}()
```

The answer is yes. We create a slice with `make([]int, 0, 1)`. Therefore, the array isn’t full. Both goroutines attempt to update the same index of the backing array (index 1), which is a data race.

How can we prevent the data race if we want both goroutines to work on a slice containing the initial elements of `s` plus an extra element? One solution is to create a copy of `s`.

We should remember that using append on a shared slice in concurrent applications can lead to a data race. Hence, it should be avoided.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/69-data-race-append/main.go)

Upstream: https://100go.co/#creating-data-races-with-append-69

## Using mutexes inaccurately with slices and maps (#70)

**One line:** Remembering that slices and maps are pointers can prevent common data races.

Let's implement a `Cache` struct used to handle caching for customer balances. This struct will contain a map of balances per customer ID and a mutex to protect concurrent accesses:

```go
type Cache struct {
    mu       sync.RWMutex
    balances map[string]float64
}
```

Next, we add an `AddBalance` method that mutates the `balances` map. The mutation is done in a critical section (within a mutex lock and a mutex unlock):

```go
func (c *Cache) AddBalance(id string, balance float64) {
    c.mu.Lock()
    c.balances[id] = balance
    c.mu.Unlock()
}
```

Meanwhile, we have to implement a method to calculate the average balance for all the customers. One idea is to handle a minimal critical section this way:

```go
func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    balances := c.balances // Creates a copy of the balances map
    c.mu.RUnlock()

    sum := 0.
    for _, balance := range balances { // Iterates over the copy, outside of the critical section
        sum += balance
    }
    return sum / float64(len(balances))
}
```

What's the problem with this code?

If we run a test using the `-race` flag with two concurrent goroutines, one calling `AddBalance` (hence mutating balances) and another calling `AverageBalance`, a data race occurs. What’s the problem here?

Internally, a map is a `runtime.hmap` struct containing mostly metadata (for example, a counter) and a pointer referencing data buckets. So, `balances := c.balances` doesn’t copy the actual data. Therefore, the two goroutines perform operations on the same data set, and one mutates it. Hence, it's a data race.

One possible solution is to protect the whole `AverageBalance` function:

```go hl_lines="2 3"
func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    defer c.mu.RUnlock() // Unlocks when the function returns

    sum := 0.
    for _, balance := range c.balances {
        sum += balance
    }
    return sum / float64(len(c.balances))
}
```

Another option, if the iteration operation isn’t lightweight, is to work on an actual copy of the data and protect only the copy:

```go hl_lines="2 3 4 5 6 7"
func (c *Cache) AverageBalance() float64 {
    c.mu.RLock()
    m := maps.Clone(c.balances)
    c.mu.RUnlock()

    sum := 0.
    for _, balance := range m {
        sum += balance
    }
    return sum / float64(len(m))
}
```

Once we have made a deep copy, we release the mutex. The iterations are done on the copy outside of the critical section.

In summary, we have to be careful with the boundaries of a mutex lock. In this section, we have seen why assigning an existing map (or an existing slice) to a map isn’t enough to protect against data races. The new variable, whether a map or a slice, is backed by the same data set. There are two leading solutions to prevent this: protect the whole function, or work on a copy of the actual data. In all cases, let’s be cautious when designing critical sections and make sure the boundaries are accurately defined.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/70-mutex-slices-maps/main.go)

Upstream: https://100go.co/#using-mutexes-inaccurately-with-slices-and-maps-70

## Misusing `sync.WaitGroup` (#71)

**One line:** To accurately use `sync.WaitGroup`, call the `Add` method before spinning up goroutines.

In the following example, we will initialize a wait group, start three goroutines that will update a counter atomically, and then wait for them to complete. We want to wait for these three goroutines to print the value of the counter (which should be 3):

```go
wg := sync.WaitGroup{}
var v uint64
for i := 0; i < 3; i++ {
    go func() {
        wg.Add(1)
        atomic.AddUint64(&v, 1)
        wg.Done()
    }()
}
wg.Wait()
fmt.Println(v)
```

If we run this example, we get a non-deterministic value: the code can print any value from 0 to 3. Also, if we enable the `-race` flag, Go will even catch a data race.

The problem is that `wg.Add(1)` is called within the newly created goroutine, not in the parent goroutine. Hence, there is no guarantee that we have indicated to the wait group that we want to wait for three goroutines before calling `wg.Wait()`.

To fix this issue, we can call `wg.Add` before the loop:

```go
wg := sync.WaitGroup{}
var v uint64
wg.Add(3)
for i := 0; i < 3; i++ {
    go func() {
        atomic.AddUint64(&v, 1)
        wg.Done()
    }()
}
wg.Wait()
fmt.Println(v)
```

Or inside the loop but not in the newly created goroutine:

```go
wg := sync.WaitGroup{}
var v uint64
for i := 0; i < 3; i++ {
    wg.Add(1)
    go func() {
        atomic.AddUint64(&v, 1)
        wg.Done()
    }()
}
wg.Wait()
fmt.Println(v)
```

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/71-wait-group/main.go)

Upstream: https://100go.co/#misusing-sync-waitgroup-71

## Forgetting about `sync.Cond` (#72)

**One line:** You can send repeated notifications to multiple goroutines with `sync.Cond`.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/72-cond/main.go)

Upstream: https://100go.co/#forgetting-about-sync-cond-72

## Not using `errgroup` (#73)

**One line:** You can synchronize a group of goroutines and handle errors and contexts with the `errgroup` package.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/73-errgroup/main.go)

Upstream: https://100go.co/#not-using-errgroup-73

## Copying a `sync` type (#74)

**One line:** `sync` types shouldn’t be copied.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/09-concurrency-practice/74-copying-sync/main.go)

Upstream: https://100go.co/#copying-a-sync-type-74
