# <feature> — plan (failing tests, written here before any implementation)

Each entry is one failing test, written in this document first — never in the test file.
Each was probed with `bin/probe.sh` and printed RED before it was added here. The loop takes the next unchecked entry, copies its code **verbatim** into the suite,
watches it fail, implements the minimum, refactors, checks the box. The gate verifies
that the test function named in every checked entry was added to the suite.

Entry format: `- [ ] TestName — one line: what it proves` (name the behavior, as CLAUDE.md asks)
followed by a fenced code block with the complete test function.

## Small feature 1: <name>

- [ ] TestAdd_SumsTwoPositives — 1 + 2 = 3.
```go
func TestAdd_SumsTwoPositives(t *testing.T) {
	if got := Add(1, 2); got != 3 {
		t.Fatalf("Add(1,2) = %d, want 3", got)
	}
}
```

- [ ] TestAdd_ZeroIsIdentity — adding 0 returns the other operand.
```go
func TestAdd_ZeroIsIdentity(t *testing.T) {
	if got := Add(0, 5); got != 5 {
		t.Fatalf("Add(0,5) = %d, want 5", got)
	}
}
```

- [ ] TestAdd_Overflow — <boundary case>.
```go
...
```

## Small feature 2: <name>

- [ ] Test... — <empty / duplicate / error path / ordering>.
```go
...
```

## Notes
- More entries is better: simplest, empty/zero, boundaries, duplicates, error paths, ordering.
- Structural changes go in their own commit (Tidy First).
- Add an entry here the moment you think of it; never skip ahead in the list.
