# <feature> — plan (failing tests, written here before any implementation)

Each entry is one failing test, written in this document first — never in the test file.
Each was probed with `bin/probe.sh` and printed RED before it was added here. The loop takes the next unchecked entry, copies its code **verbatim** into the suite,
watches it fail, implements the minimum, refactors, checks the box. The gate verifies
that the test function named in every checked entry was added to the suite.

Entry format: `- [ ] TestName — one line: what it proves` (name the behavior), then a fenced code
block holding exactly what the loop appends to the suite.

Every entry follows the four rules in `tdd-set/skills/tdd/SKILL.md`: isolated (own fixture,
any order), shared setup only in the section header, evident data in the body, readable and
specific over short.

- Go: the complete test function. The loop appends it to the package's `_test.go` file.
- Node: one `test(...)` block whose title starts with the entry name. Each `## Small feature`
  section opens with a **header block**: a `// file:` line naming the test file (relative to the
  app root), the imports, and the shared constants. The loop creates that file from the header the
  first time and appends each entry block to its end. The header is never repeated per entry.

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

## Small feature 3 (Node example): <name>

```ts
// file: tests/add.test.ts
import { test } from 'node:test'
import assert from 'node:assert/strict'
import { add } from '../src/add.js'
const BIG = 1_000_000
```

- [ ] addAdds — 1 + 2 = 3.
```ts
test('addAdds: 1 + 2 = 3', () => {
  assert.equal(add(1, 2), 3)
})
```

- [ ] addZeroIsIdentity — adding 0 returns the other operand.
```ts
test('addZeroIsIdentity: 0 + BIG = BIG', () => {
  assert.equal(add(0, BIG), BIG)
})
```

## Notes
- More entries is better: simplest, empty/zero, boundaries, duplicates, error paths, ordering.
- Structural changes go in their own commit (Tidy First).
- Add an entry here the moment you think of it; never skip ahead in the list.
