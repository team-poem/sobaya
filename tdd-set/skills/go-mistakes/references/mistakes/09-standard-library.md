# Standard Library

Source: [100go.co](https://100go.co/#standard-library)

## Providing a wrong time duration (#75)

**One line:** Remain cautious with functions accepting a `time.Duration`. Even though passing an integer is allowed, strive to use the time API to prevent any possible confusion.

Many common functions in the standard library accept a `time.Duration`, which is an alias for the `int64` type. However, one `time.Duration` unit represents one nanosecond, instead of one millisecond, as commonly seen in other programming languages. As a result, passing numeric types instead of using the `time.Duration` API can lead to unexpected behavior.

A developer with experience in other languages might assume that the following code creates a new `time.Ticker` that delivers ticks every second, given the value `1000`:

```go
ticker := time.NewTicker(1000)
for {
	select {
	case <-ticker.C:
		// Do something
	}
}
```

However, because 1,000 `time.Duration` units = 1,000 nanoseconds, ticks are delivered every 1,000 nanoseconds = 1 microsecond, not every second as assumed.

We should always use the `time.Duration` API to avoid confusion and unexpected behavior:
```go
ticker = time.NewTicker(time.Microsecond)
// Or
ticker = time.NewTicker(1000 * time.Nanosecond)
```

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/75-wrong-time-duration/main.go)

Upstream: https://100go.co/#providing-a-wrong-time-duration-75

## `time.After` and memory leaks (#76)

**Warning:**

This mistake isn't relevant anymore from Go 1.23 ([details](https://go.dev/wiki/Go123Timer)).

Upstream: https://100go.co/#time-after-and-memory-leaks-76

## JSON handling common mistakes (#77)

* Unexpected behavior because of type embedding

  Be careful about using embedded fields in Go structs. Doing so may lead to sneaky bugs like an embedded time.Time field implementing the `json.Marshaler` interface, hence overriding the default marshaling behavior.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/type-embedding/main.go)

* JSON and the monotonic clock

  When comparing two `time.Time` structs, recall that `time.Time` contains both a wall clock and a monotonic clock, and the comparison using the == operator is done on both clocks.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/monotonic-clock/main.go)

* Map of `any`

  To avoid wrong assumptions when you provide a map while unmarshaling JSON data, remember that numerics are converted to `float64` by default.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/77-json-handling/map-any/main.go)

Upstream: https://100go.co/#json-handling-common-mistakes-77

## Common SQL mistakes (#78)

* Forgetting that `sql.Open` doesn't necessarily establish connections to a database

  Call the `Ping` or `PingContext` method if you need to test your configuration and make sure a database is reachable.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/sql-open)

* Forgetting about connections pooling

  Configure the database connection parameters for production-grade applications.

* Not using prepared statements

  Using SQL prepared statements makes queries more efficient and more secure.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/prepared-statements)

* Mishandling null values

  Deal with nullable columns in tables using pointers or `sql.NullXXX` types.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/null-values/main.go)

* Not handling rows iteration errors

  Call the `Err` method of `sql.Rows` after row iterations to ensure that you haven’t missed an error while preparing the next row.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/78-sql/rows-iterations-errors)

Upstream: https://100go.co/#common-sql-mistakes-78

## Not closing transient resources (HTTP body, `sql.Rows`, and `os.File`) (#79)

**One line:** Eventually close all structs implementing `io.Closer` to avoid possible leaks.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/79-closing-resources/)

Upstream: https://100go.co/#not-closing-transient-resources-http-body-sql-rows-and-os-file-79

## Forgetting the return statement after replying to an HTTP request (#80)

**One line:** To avoid unexpected behaviors in HTTP handler implementations, make sure you don’t miss the `return` statement if you want a handler to stop after `http.Error`.

Consider the following HTTP handler that handles an error from `foo` using `http.Error`:

```go
func handler(w http.ResponseWriter, req *http.Request) {
	err := foo(req)
	if err != nil {
		http.Error(w, "foo", http.StatusInternalServerError)
	}

	_, _ = w.Write([]byte("all good"))
	w.WriteHeader(http.StatusCreated)
}
```

If we run this code and `err != nil`, the HTTP response would be:

```
foo
all good
```

The response contains both the error and success messages, and also the first HTTP status code, 500. There would also be a warning log indicating that we attempted to write the status code multiple times:

```
2023/10/10 16:45:33 http: superfluous response.WriteHeader call from main.handler (main.go:20)
```

The mistake in this code is that `http.Error` does not stop the handler's execution, which means the success message and status code get written in addition to the error. Beyond an incorrect response, failing to return after writing an error can lead to the unwanted execution of code and unexpected side-effects. The following code adds the `return` statement following the `http.Error` and exhibits the desired behavior when ran:

```go
func handler(w http.ResponseWriter, req *http.Request) {
	err := foo(req)
	if err != nil {
		http.Error(w, "foo", http.StatusInternalServerError)
		return // Adds the return statement
	}

	_, _ = w.Write([]byte("all good"))
	w.WriteHeader(http.StatusCreated)
}
```

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/80-http-return/main.go)

Upstream: https://100go.co/#forgetting-the-return-statement-after-replying-to-an-http-request-80

## Using the default HTTP client and server (#81)

**One line:** For production-grade applications, don’t use the default HTTP client and server implementations. These implementations are missing timeouts and behaviors that should be mandatory in production.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/10-standard-lib/81-default-http-client-server/)

Upstream: https://100go.co/#using-the-default-http-client-and-server-81
