# Optimizations

Source: [100go.co](https://100go.co/#optimizations)

## Not understanding CPU caches (#91)

* CPU architecture

  Understanding how to use CPU caches is important for optimizing CPU-bound applications because the L1 cache is about 50 to 100 times faster than the main memory.

* Cache line

  Being conscious of the cache line concept is critical to understanding how to organize data in data-intensive applications. A CPU doesn’t fetch memory word by word; instead, it usually copies a memory block to a 64-byte cache line. To get the most out of each individual cache line, enforce spatial locality.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/cache-line/)

* Slice of structs vs. struct of slices

<!-- TODO -->

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/slice-structs/)

* Predictability

  Making code predictable for the CPU can also be an efficient way to optimize certain functions. For example, a unit or constant stride is predictable for the CPU, but a non-unit stride (for example, a linked list) isn’t predictable.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/91-cpu-caches/predictability/)

* Cache placement policy

  To avoid a critical stride, hence utilizing only a tiny portion of the cache, be aware that caches are partitioned.

Upstream: https://100go.co/#not-understanding-cpu-caches-91

## Writing concurrent code that leads to false sharing (#92)

**One line:** Knowing that lower levels of CPU caches aren’t shared across all the cores helps avoid performance-degrading patterns such as false sharing while writing concurrency code. Sharing memory is an illusion.

Read the full section [here](deep-dives/92-false-sharing.md).

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/92-false-sharing/)

Upstream: https://100go.co/#writing-concurrent-code-that-leads-to-false-sharing-92

## Not taking into account instruction-level parallelism (#93)

**One line:** Use ILP to optimize specific parts of your code to allow a CPU to execute as many parallel instructions as possible. Identifying data hazards is one of the main steps.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/93-instruction-level-parallelism/)

Upstream: https://100go.co/#not-taking-into-account-instruction-level-parallelism-93

## Not being aware of data alignment (#94)

**One line:** You can avoid common mistakes by remembering that in Go, basic types are aligned with their own size. For example, keep in mind that reorganizing the fields of a struct by size in descending order can lead to more compact structs (less memory allocation and potentially a better spatial locality).

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/94-data-alignment/)

Upstream: https://100go.co/#not-being-aware-of-data-alignment-94

## Not understanding stack vs. heap (#95)

**One line:** Understanding the fundamental differences between heap and stack should also be part of your core knowledge when optimizing a Go application. Stack allocations are almost free, whereas heap allocations are slower and rely on the GC to clean the memory.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/95-stack-heap/)

Upstream: https://100go.co/#not-understanding-stack-vs-heap-95

## Not knowing how to reduce allocations (API change, compiler optimizations, and `sync.Pool`) (#96)

**One line:** Reducing allocations is also an essential aspect of optimizing a Go application. This can be done in different ways, such as designing the API carefully to prevent sharing up, understanding the common Go compiler optimizations, and using `sync.Pool`.

 [Source code](https://github.com/teivah/100-go-mistakes/tree/master/src/12-optimizations/96-reduce-allocations/)

Upstream: https://100go.co/#not-knowing-how-to-reduce-allocations-api-change-compiler-optimizations-and-sync-pool-96

## Not relying on inlining (#97)

**One line:** Use the fast-path inlining technique to efficiently reduce the amortized time to call a function.

Upstream: https://100go.co/#not-relying-on-inlining-97

## Not using Go diagnostics tooling (#98)

**One line:** Rely on profiling and the execution tracer to understand how an application performs and the parts to optimize.

Read the full section [here](deep-dives/98-profiling-execution-tracing.md).

Upstream: https://100go.co/#not-using-go-diagnostics-tooling-98

## Not understanding how the GC works (#99)

**One line:** Understanding how to tune the GC can lead to multiple benefits such as handling sudden load increases more efficiently.

Upstream: https://100go.co/#not-understanding-how-the-gc-works-99

## Not understanding the impacts of running Go in Docker and Kubernetes (#100)

**One line:** Obsolete since Go 1.25: the runtime sets GOMAXPROCS from the container CPU limit itself.

**Warning:**

This mistake isn't relevant anymore from Go 1.25 ([details](https://go.dev/blog/container-aware-gomaxprocs)).


Upstream: https://100go.co/#warning-not-understanding-the-impacts-of-running-go-in-docker-and-kubernetes-100
