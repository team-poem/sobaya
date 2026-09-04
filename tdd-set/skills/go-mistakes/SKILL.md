---
name: go-mistakes
description: >-
  Go refactor pass for the TDD loop's green phase, driven by the 100 Go Mistakes catalog (Teiva
  Harsanyi) mirrored locally with full bodies. Applies to an app whose AGENTS.md `Skills:` line
  names go-mistakes. Use after a test goes green, before commit. Names each hit by number (#25);
  structural changes only, tests must stay green after every step.
---

# Go Mistakes (refactor while green)

`references/mistakes-map.md` lists all 100 mistakes as title + one-line TL;DR; the chapter files
under `references/mistakes/` hold the full bodies. Read the map, then only the chapters the change
touches. Never cite a mistake you did not open.

## Select chapters by what changed

| Change touches | Read |
|---|---|
| package layout, interfaces, options, `init`, generics, embedding | `01-code-and-project-organization.md` |
| slices, maps, numbers, comparisons | `02-data-types.md` |
| `range`, `break`, `defer` in loops, map iteration | `03-control-structures.md` |
| runes, trimming, concatenation, substrings | `04-strings.md` |
| receivers, named results, nil receivers, `defer` evaluation | `05-functions-and-methods.md` |
| `error` creation, wrapping, comparison, handling | `06-error-management.md` |
| goroutines, channels, mutexes, `context`, `sync`, `errgroup` | `07-concurrency-foundations.md`, `08-concurrency-practice.md` |
| `time`, JSON, SQL, HTTP client/server, resource closing | `09-standard-library.md` |
| `_test.go` files, benchmarks, race flag | `10-testing.md` |
| a hot path, allocations, GC pressure | `11-optimizations.md` |

Skip chapters the diff does not touch. #100 (GOMAXPROCS in containers) is obsolete since Go 1.25.

## Refactor step (suite green)

1. Run the app's `- Format:` and `- Lint:` lines; fix before anything else.
2. For each selected chapter, walk its mistakes against the new code only. Stop at the first hit,
   fix it as one structural change, run the full suite, continue.
3. Never rename, move, or change the signature of anything a test references: the tests are the
   spec and the gate rejects any edit to them; a name the tests use is fixed until a human changes
   failed-test.md.
4. Touched a hot path? Run the AGENTS.md `Bench:` command before and after and put both numbers in
   the `refactor:` commit message. A regression is not a refactor — revert it.
5. Commit structural changes in their own commit, message prefixed `refactor:`, never mixed with a
   behavioral change.
