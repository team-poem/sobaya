# <feature> — approved test plan

Replace these examples with the human's reviewed acceptance cases. Keep only
sections for the app's stack. Draft cases are not approved until the human
reviews the committed spec, commands, exact headers, and test bodies.

Each entry is `- [ ] UniqueName — behavior`, followed by one fenced test.
The section header names the destination with `// file:` and contains exact
package/import/setup code. The runner appends each body verbatim, observes
failure, and checks the box only after the full suite passes. Do not edit
approved entries during implementation; changed criteria need renewed approval.

## Go example

```go
// file: add_test.go
package example

import "testing"
```

- [ ] TestAdd_SumsTwoPositives — 1 + 2 = 3.
```go
func TestAdd_SumsTwoPositives(t *testing.T) {
	if got := Add(1, 2); got != 3 {
		t.Fatalf("Add(1,2) = %d, want 3", got)
	}
}
```

## Node example

```js
// file: add.test.js
const test = require('node:test');
const assert = require('node:assert/strict');
const { add } = require('./add.js');
```

- [ ] addAdds — 1 + 2 = 3.
```js
test('addAdds: 1 + 2 = 3', () => {
  assert.equal(add(1, 2), 3);
});
```

## Review notes

Include meaningful boundaries, invalid inputs, and error cases relevant to the
spec. Each identifier must match a real test registered by the declared suite.
Probe draft candidates before approval; distinguish behavioral failures from
missing runtimes, dependencies, syntax errors, and skipped tests. Never treat
a successful shell command without executed tests as acceptance evidence.
