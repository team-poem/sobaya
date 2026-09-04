# Testing

Source: [100go.co](https://100go.co/#testing)

## Not categorizing tests (build tags, environment variables, and short mode) (#82)

**One line:** Categorizing tests using build flags, environment variables, or short mode makes the testing process more efficient. You can create test categories using build flags or environment variables (for example, unit versus integration tests) and differentiate short from long-running tests to decide which kinds of tests to execute.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/82-categorizing-tests/)

Upstream: https://100go.co/#not-categorizing-tests-build-tags-environment-variables-and-short-mode-82

## Not enabling the race flag (#83)

**One line:** Enabling the `-race` flag is highly recommended when writing concurrent applications. Doing so allows you to catch potential data races that can lead to software bugs.

In Go, the race detector isn’t a static analysis tool used during compilation; instead, it’s a tool to find data races that occur at runtime. To enable it, we have to enable the -race flag while compiling or running a test. For example:

```bash
go test -race ./...
```

Once the race detector is enabled, the compiler instruments the code to detect data races. Instrumentation refers to a compiler adding extra instructions: here, tracking all memory accesses and recording when and how they occur.

Enabling the race detector adds an overhead in terms of memory and execution time; hence, it's generally recommended to enable it only during local testing or continuous integration, not production.

If a race is detected, Go raises a warning. For example:

```go
package main

import (
    "fmt"
)

func main() {
    i := 0
    go func() { i++ }()
    fmt.Println(i)
}
```

Running this code with the `-race` logs the following warning:

```bash hl_lines="3 7 11"
==================
WARNING: DATA RACE
Write at 0x00c000026078 by goroutine 7: # (1)
  main.main.func1()
      /tmp/app/main.go:9 +0x4e

Previous read at 0x00c000026078 by main goroutine: # (2)
  main.main()
      /tmp/app/main.go:10 +0x88

Goroutine 7 (running) created at: # (3)
  main.main()
      /tmp/app/main.go:9 +0x7a
==================
```

1.  Indicates that goroutine 7 was writing
2.  Indicates that the main goroutine was reading
3.  Indicates when the goroutine 7 was created

Let’s make sure we are comfortable reading these messages. Go always logs the following:

* The concurrent goroutines that are incriminated: here, the main goroutine and goroutine 7.
* Where accesses occur in the code: in this case, lines 9 and 10.
* When these goroutines were created: goroutine 7 was created in main().

In addition, if a specific file contains tests that lead to data races, we can exclude it :material-information-outline:{ title="temporarily! 😉" } from race detection using the `!race` build tag:

```go
//go:build !race

package main

import (
    "testing"
)

func TestFoo(t *testing.T) {
    // ...
}
```

Upstream: https://100go.co/#not-enabling-the-race-flag-83

## Not using test execution modes (parallel and shuffle) (#84)

**One line:** Using the `-parallel` flag is an efficient way to speed up tests, especially long-running ones. Use the `-shuffle` flag to help ensure that a test suite doesn’t rely on wrong assumptions that could hide bugs.

Upstream: https://100go.co/#not-using-test-execution-modes-parallel-and-shuffle-84

## Not using table-driven tests (#85)

**One line:** Table-driven tests are an efficient way to group a set of similar tests to prevent code duplication and make future updates easier to handle.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/85-table-driven-tests/main_test.go)

Upstream: https://100go.co/#not-using-table-driven-tests-85

## Sleeping in unit tests (#86)

**One line:** Avoid sleeps using synchronization to make a test less flaky and more robust. If synchronization isn’t possible, consider a retry approach.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/86-sleeping/main_test.go)

Upstream: https://100go.co/#sleeping-in-unit-tests-86

## Not dealing with the time API efficiently (#87)

**One line:** Understanding how to deal with functions using the time API is another way to make a test less flaky. You can use standard techniques such as handling the time as part of a hidden dependency or asking clients to provide it.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/87-time-api/)

Upstream: https://100go.co/#not-dealing-with-the-time-api-efficiently-87

## Not using testing utility packages (`httptest` and `iotest`) (#88)

* The `httptest` package is helpful for dealing with HTTP applications. It provides a set of utilities to test both clients and servers.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/88-utility-package/httptest/main_test.go)

* The `iotest` package helps write io.Reader and test that an application is tolerant to errors.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/88-utility-package/iotest/main_test.go)

Upstream: https://100go.co/#not-using-testing-utility-packages-httptest-and-iotest-88

## Writing inaccurate benchmarks (#89)

**One line:** Regarding benchmarks:

* Use time methods to preserve the accuracy of a benchmark.
* Increasing benchtime or using tools such as benchstat can be helpful when dealing with micro-benchmarks.
* Be careful with the results of a micro-benchmark if the system that ends up running the application is different from the one running the micro-benchmark.
* Make sure the function under test leads to a side effect, to prevent compiler optimizations from fooling you about the benchmark results.
* To prevent the observer effect, force a benchmark to re-create the data used by a CPU-bound function.

Read the full section [here](deep-dives/89-benchmarks.md).

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/89-benchmark/)

Upstream: https://100go.co/#writing-inaccurate-benchmarks-89

## Not exploring all the Go testing features (#90)

* Code coverage

  Use code coverage with the `-coverprofile` flag to quickly see which part of the code needs more attention.

* Testing from a different package

  Place unit tests in a different package to enforce writing tests that focus on an exposed behavior, not internals.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/different-package/main_test.go)

* Utility functions

  Handling errors using the `*testing.T` variable instead of the classic `if err != nil` makes code shorter and easier to read.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/utility-function/main_test.go)

* Setup and teardown

  You can use setup and teardown functions to configure a complex environment, such as in the case of integration tests.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/11-testing/90-testing-features/setup-teardown/main_test.go)

Upstream: https://100go.co/#not-exploring-all-the-go-testing-features-90

## Not using fuzzing (community mistake)

**One line:** Fuzzing is an efficient strategy to detect random, unexpected, or malformed inputs to complex functions and methods in order to discover vulnerabilities, bugs, or even potential crashes.

Credits: [@jeromedoucet](https://github.com/jeromedoucet)

Upstream: https://100go.co/#not-using-fuzzing-community-mistake
