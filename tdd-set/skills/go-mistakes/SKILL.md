---
name: go-mistakes
description: >-
  Go refactor pass for the TDD loop's green phase, driven by the 100 Go Mistakes catalog (Teiva
  Harsanyi) mirrored locally with full bodies. Applies to an app whose AGENTS.md `Skills:` line
  names go-mistakes. Use for relevant optional structural tidying at a verified GREEN checkpoint. Names each hit by number (#25);
  structural changes only, tests must stay green after every step.
---

# Go Mistakes (refactor while green)

Apply as orchestrator-led tidying within the authorized development task,
after the implementation worker has finished its verified entry. Follow
`tdd-set/AGENTS.md` for the cycle and current runtime limits. Preserve tested behavior and assertion strength. Inspect only concrete friction in the current
change; skip this pass when no useful improvement is apparent.

The chapter files under `references/mistakes/` hold the full bodies; `references/mistakes-map.md`
(30KB) lists all 100 as title + one-line TL;DR. Start with the chapter the
diff touches most; open additional chapters only when the change warrants
them. Use the map for broader package reviews. Never cite a mistake you
did not open.

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
3. Refactor source and test references together at GREEN when useful. Preserve behavior and
   assertions and rerun the suite; test identifiers and interfaces are not permanently frozen.
4. Touched a hot path? Run the AGENTS.md `Bench:` command before and after and put both numbers in
   the `refactor:` commit message. If performance or behavior regresses,
   stop and diagnose; do not advance or discard unrelated edits.
5. Commit structural changes in their own commit, message prefixed `refactor:`, never mixed with a
   behavioral change.
