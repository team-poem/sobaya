# Strings

Source: [100go.co](https://100go.co/#strings)

## Not understanding the concept of rune (#36)

**One line:** Understanding that a rune corresponds to the concept of a Unicode code point and that it can be composed of multiple bytes should be part of the Go developer’s core knowledge to work accurately with strings.

As runes are everywhere in Go, it's important to understand the following:

* A charset is a set of characters, whereas an encoding describes how to translate a charset into binary.
* In Go, a string references an immutable slice of arbitrary bytes.
* Go source code is encoded using UTF-8. Hence, all string literals are UTF-8 strings. But because a string can contain arbitrary bytes, if it’s obtained from somewhere else (not the source code), it isn’t guaranteed to be based on the UTF-8 encoding.
* A `rune` corresponds to the concept of a Unicode code point, meaning an item represented by a single value.
* Using UTF-8, a Unicode code point can be encoded into 1 to 4 bytes.
* Using `len()` on a string in Go returns the number of bytes, not the number of runes.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/36-rune/main.go)

Upstream: https://100go.co/#not-understanding-the-concept-of-rune-36

## Inaccurate string iteration (#37)

**One line:** Iterating on a string with the `range` operator iterates on the runes with the index corresponding to the starting index of the rune’s byte sequence. To access a specific rune index (such as the third rune), convert the string into a `[]rune`.

Iterating on a string is a common operation for developers. Perhaps we want to perform an operation for each rune in the string or implement a custom function to search for a specific substring. In both cases, we have to iterate on the different runes of a string. But it’s easy to get confused about how iteration works.

For example, consider the following example:

```go
s := "hêllo"
for i := range s {
    fmt.Printf("position %d: %c\n", i, s[i])
}
fmt.Printf("len=%d\n", len(s))
```

```
position 0: h
position 1: Ã
position 3: l
position 4: l
position 5: o
len=6
```

Let's highlight three points that might be confusing:

* The second rune is Ã in the output instead of ê.
* We jumped from position 1 to position 3: what is at position 2?
* len returns a count of 6, whereas s contains only 5 runes.

Let’s start with the last observation. We already mentioned that len returns the number of bytes in a string, not the number of runes. Because we assigned a string literal to `s`, `s` is a UTF-8 string. Meanwhile, the special character "ê" isn’t encoded in a single byte; it requires 2 bytes. Therefore, calling `len(s)` returns 6.

Meanwhile, in the previous example, we have to understand that we don't iterate over each rune; instead, we iterate over each starting index of a rune:

![](https://raw.githubusercontent.com/teivah/100-go-mistakes/master/docs/img/rune.png)

Printing `s[i]` doesn’t print the ith rune; it prints the UTF-8 representation of the byte at index `i`. Hence, we printed "hÃllo" instead of "hêllo".

If we want to print all the different runes, we can either use the value element of the `range` operator:

```go
s := "hêllo"
for i, r := range s {
    fmt.Printf("position %d: %c\n", i, r)
}
```

Or, we can convert the string into a slice of runes and iterate over it:

```go hl_lines="2"
s := "hêllo"
runes := []rune(s)
for i, r := range runes {
    fmt.Printf("position %d: %c\n", i, r)
}
```

Note that this solution introduces a run-time overhead compared to the previous one. Indeed, converting a string into a slice of runes requires allocating an additional slice and converting the bytes into runes: an O(n) time complexity with n the number of bytes in the string. Therefore, if we want to iterate over all the runes, we should use the first solution.

However, if we want to access the ith rune of a string with the first option, we don’t have access to the rune index; rather, we know the starting index of a rune in the byte sequence.

```go
s := "hêllo"
r := []rune(s)[4]
fmt.Printf("%c\n", r) // o
```

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/37-string-iteration/main.go)

Upstream: https://100go.co/#inaccurate-string-iteration-37

## Misusing trim functions (#38)

**One line:** `strings.TrimRight`/`strings.TrimLeft` removes all the trailing/leading runes contained in a given set, whereas `strings.TrimSuffix`/`strings.TrimPrefix` returns a string without a provided suffix/prefix.

For example:

```go
fmt.Println(strings.TrimRight("123oxo", "xo"))
```

The example prints 123:

![](https://raw.githubusercontent.com/teivah/100-go-mistakes/master/docs/img/trim.png)

Conversely, `strings.TrimLeft` removes all the leading runes contained in a set.

On the other side, `strings.TrimSuffix` / `strings.TrimPrefix` returns a string without the provided trailing suffix / prefix.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/38-trim/main.go)

Upstream: https://100go.co/#misusing-trim-functions-38

## Under-optimized strings concatenation (#39)

**One line:** Concatenating a list of strings should be done with `strings.Builder` to prevent allocating a new string during each iteration.

Let’s consider a `concat` function that concatenates all the string elements of a slice using the `+=` operator:

```go
func concat(values []string) string {
    s := ""
    for _, value := range values {
        s += value
    }
    return s
}
```

During each iteration, the `+=` operator concatenates `s` with the value string. At first sight, this function may not look wrong. But with this implementation, we forget one of the core characteristics of a string: its immutability. Therefore, each iteration doesn’t update `s`; it reallocates a new string in memory, which significantly impacts the performance of this function.

Fortunately, there is a solution to deal with this problem, using `strings.Builder`:

```go hl_lines="2 4"
func concat(values []string) string {
    sb := strings.Builder{}
    for _, value := range values {
        _, _ = sb.WriteString(value)
    }
    return sb.String()
}
```

During each iteration, we constructed the resulting string by calling the `WriteString` method that appends the content of value to its internal buffer, hence minimizing memory copying.

**Note:**

`WriteString` returns an error as the second output, but we purposely ignore it. Indeed, this method will never return a non-nil error. So what’s the purpose of this method returning an error as part of its signature? `strings.Builder` implements the `io.StringWriter` interface, which contains a single method: `WriteString(s string) (n int, err error)`. Hence, to comply with this interface, `WriteString` must return an error.

Internally, `strings.Builder` holds a byte slice. Each call to `WriteString` results in a call to append on this slice. There are two impacts. First, this struct shouldn’t be used concurrently, as the calls to `append` would lead to race conditions. The second impact is something that we saw in [mistake #21, "Inefficient slice initialization"](#inefficient-slice-initialization-21): if the future length of a slice is already known, we should preallocate it. For that purpose, `strings.Builder` exposes a method `Grow(n int)` to guarantee space for another `n` bytes:

```go
func concat(values []string) string {
    total := 0
    for i := 0; i < len(values); i++ {
        total += len(values[i])
    }

    sb := strings.Builder{}
    sb.Grow(total) (2)
    for _, value := range values {
        _, _ = sb.WriteString(value)
    }
    return sb.String()
}
```

Let’s run a benchmark to compare the three versions (v1 using `+=`; v2 using `strings.Builder{}` without preallocation; and v3 using `strings.Builder{}` with preallocation). The input slice contains 1,000 strings, and each string contains 1,000 bytes:

```
BenchmarkConcatV1-4             16      72291485 ns/op
BenchmarkConcatV2-4           1188        878962 ns/op
BenchmarkConcatV3-4           5922        190340 ns/op
```

As we can see, the latest version is by far the most efficient: 99% faster than v1 and 78% faster than v2.

`strings.Builder` is the recommended solution to concatenate a list of strings. Usually, this solution should be used within a loop. Indeed, if we just have to concatenate a few strings (such as a name and a surname), using `strings.Builder` is not recommended as doing so will make the code a bit less readable than using the `+=` operator or `fmt.Sprintf`.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/39-string-concat/)

Upstream: https://100go.co/#under-optimized-strings-concatenation-39

## Useless string conversions (#40)

**One line:** Remembering that the `bytes` package offers the same operations as the `strings` package can help avoid extra byte/string conversions.

When choosing to work with a string or a `[]byte`, most programmers tend to favor strings for convenience. But most I/O is actually done with `[]byte`. For example, `io.Reader`, `io.Writer`, and `io.ReadAll` work with `[]byte`, not strings.

When we’re wondering whether we should work with strings or `[]byte`, let’s recall that working with `[]byte` isn’t necessarily less convenient. Indeed, all the exported functions of the strings package also have alternatives in the `bytes` package: `Split`, `Count`, `Contains`, `Index`, and so on. Hence, whether we’re doing I/O or not, we should first check whether we could implement a whole workflow using bytes instead of strings and avoid the price of additional conversions.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/40-string-conversion/main.go)

Upstream: https://100go.co/#useless-string-conversions-40

## Substring and memory leaks (#41)

**One line:** Using copies instead of substrings can prevent memory leaks, as the string returned by a substring operation will be backed by the same byte array.

In mistake [#26, “Slices and memory leaks,”](#slice-and-memory-leaks--26-) we saw how slicing a slice or array may lead to memory leak situations. This principle also applies to string and substring operations.

We need to keep two things in mind while using the substring operation in Go. First, the interval provided is based on the number of bytes, not the number of runes. Second, a substring operation may lead to a memory leak as the resulting substring will share the same backing array as the initial string. The solutions to prevent this case from happening are to perform a string copy manually or to use `strings.Clone` from Go 1.18.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/05-strings/41-substring-memory-leak/main.go)

Upstream: https://100go.co/#substring-and-memory-leaks-41
