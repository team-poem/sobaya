# Dispatch patterns

Use these templates only when a bounded independent task justifies a
separate agent. Replace placeholders; omit irrelevant fields.

## Explore

```text
Read <checkout> to answer <specific question>.
Context: <why this decision matters>. Start at <entry points>.
Read-only scope: <files or subsystem>. Do not edit.
Return the answer, supporting path:line evidence, and uncertainty.
```

## Implement

```text
Work only in <absolute isolated checkout>.
Implement <bounded authorized behavior or approved entry>.
Read the applicable AGENTS.md files and relevant stack skill.
Protected inputs: spec.md, approved failed-test.md, existing tests and
support, and <other agent-owned paths>. Do not change acceptance criteria.
Use explicit working directories. Follow the harness checkpoint process.
Keep behavioral and structural commits separate when commits are in scope.
Persist progress in <artifact path> before a long handoff.
Return changed files, exact verification, unresolved issues, and state
needed to resume. Do not expand scope or switch worker policy silently.
```

Give parallel writers separate worktrees and disjoint ownership. Merge one
at a time and verify each integration.

## Review

```text
Independently review <revision range / checkout> against <approved goal>.
Try to refute correctness, completeness, and scope. Inspect edge cases,
vacuous or missing coverage, integration, and protected-input integrity.
For each actionable finding provide severity, file:line, failure scenario,
and evidence. Distinguish reproduced failures from hypotheses.
Do not edit. If there are no findings, state the checks and their limits.
```

## Verify

```text
In <checkout>, run <bounded verification commands>.
Report commands, relevant output, exit status, and environmental limits.
On failure preserve diagnostics; do not change code or tests.
```
