# Control Structures

Source: [100go.co](https://100go.co/#control-structures)

## Ignoring that elements are copied in `range` loops (#30)

**One line:** The value element in a `range` loop is a copy. Therefore, to mutate a struct, for example, access it via its index or via a classic `for` loop (unless the element or the field you want to modify is a pointer).

A range loop allows iterating over different data structures:

* String
* Array
* Pointer to an array
* Slice
* Map
* Receiving channel

Compared to a classic for `loop`, a `range` loop is a convenient way to iterate over all the elements of one of these data structures, thanks to its concise syntax.

Yet, we should remember that the value element in a range loop is a copy. Therefore, if the value is a struct we need to mutate, we will only update the copy, not the element itself, unless the value or field we modify is a pointer. The favored options are to access the element via the index using a range loop or a classic for loop.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/30-range-loop-element-copied/)

Upstream: https://100go.co/#ignoring-that-elements-are-copied-in-range-loops-30

## Ignoring how arguments are evaluated in `range` loops (channels and arrays) (#31)

**One line:** Understanding that the expression passed to the `range` operator is evaluated only once before the beginning of the loop can help you avoid common mistakes such as inefficient assignment in channel or slice iteration.

The range loop evaluates the provided expression only once, before the beginning of the loop, by doing a copy (regardless of the type). We should remember this behavior to avoid common mistakes that might, for example, lead us to access the wrong element. For example:

```go
a := [3]int{0, 1, 2}
for i, v := range a {
    a[2] = 10
    if i == 2 {
        fmt.Println(v)
    }
}
```

This code updates the last index to 10. However, if we run this code, it does not print 10; it prints 2.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/31-range-loop-arg-evaluation/)

Upstream: https://100go.co/#ignoring-how-arguments-are-evaluated-in-range-loops-channels-and-arrays-31

## Ignoring the impacts of using pointer elements in `range` loops (#32)

**Warning:**

This mistake isn't relevant anymore from Go 1.22 ([details](https://go.dev/blog/loopvar-preview)).

Upstream: https://100go.co/#warning-ignoring-the-impacts-of-using-pointer-elements-in-range-loops-32

## Making wrong assumptions during map iterations (ordering and map insert during iteration) (#33)

**One line:** To ensure predictable outputs when using maps, remember that a map data structure:

* Doesn’t order the data by keys
* Doesn’t preserve the insertion order
* Doesn’t have a deterministic iteration order
* Doesn’t guarantee that an element added during an iteration will be produced during this iteration

<!-- TODO -->

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/33-map-iteration/main.go)

Upstream: https://100go.co/#making-wrong-assumptions-during-map-iterations-ordering-and-map-insert-during-iteration-33

## Ignoring how the `break` statement works (#34)

**One line:** Using `break` or `continue` with a label enforces breaking a specific statement. This can be helpful with `switch` or `select` statements inside loops.

A break statement is commonly used to terminate the execution of a loop. When loops are used in conjunction with switch or select, developers frequently make the mistake of breaking the wrong statement. For example:

```go
for i := 0; i < 5; i++ {
    fmt.Printf("%d ", i)

    switch i {
    default:
    case 2:
        break
    }
}
```

The break statement doesn’t terminate the `for` loop: it terminates the `switch` statement, instead. Hence, instead of iterating from 0 to 2, this code iterates from 0 to 4: `0 1 2 3 4`.

One essential rule to keep in mind is that a `break` statement terminates the execution of the innermost `for`, `switch`, or `select` statement. In the previous example, it terminates the `switch` statement.

To break the loop instead of the `switch` statement, the most idiomatic way is to use a label:

```go hl_lines="1 8"
loop:
    for i := 0; i < 5; i++ {
        fmt.Printf("%d ", i)

        switch i {
        default:
        case 2:
            break loop
        }
    }
```

Here, we associate the `loop` label with the `for` loop. Then, because we provide the `loop` label to the `break` statement, it breaks the loop, not the switch. Therefore, this new version will print `0 1 2`, as we expected.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/34-break/main.go)

Upstream: https://100go.co/#ignoring-how-the-break-statement-works-34

## Using `defer` inside a loop (#35)

**One line:** Extracting loop logic inside a function leads to executing a `defer` statement at the end of each iteration.

The `defer` statement delays a call’s execution until the surrounding function returns. It’s mainly used to reduce boilerplate code. For example, if a resource has to be closed eventually, we can use `defer` to avoid repeating the closure calls before every single `return`.

One common mistake with `defer` is to forget that it schedules a function call when the _surrounding_ function returns. For example:

```go
func readFiles(ch <-chan string) error {
    for path := range ch {
        file, err := os.Open(path)
        if err != nil {
            return err
        }

        defer file.Close()

        // Do something with file
    }
    return nil
}
```

The `defer` calls are executed not during each loop iteration but when the `readFiles` function returns. If `readFiles` doesn’t return, the file descriptors will be kept open forever, causing leaks.

One common option to fix this problem is to create a surrounding function after `defer`, called during each iteration:

```go
func readFiles(ch <-chan string) error {
    for path := range ch {
        if err := readFile(path); err != nil {
            return err
        }
    }
    return nil
}

func readFile(path string) error {
    file, err := os.Open(path)
    if err != nil {
        return err
    }

    defer file.Close()

    // Do something with file
    return nil
}
```

Another solution is to make the `readFile` function a closure but intrinsically, this remains the same solution: adding another surrounding function to execute the `defer` calls during each iteration.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/04-control-structures/35-defer-loop/main.go)

Upstream: https://100go.co/#using-defer-inside-a-loop-35
