# Dispatch Patterns

Prompt templates for the brigade. Replace `<angle>` fields; delete sections
that don't apply. Every dispatch is scoped and reportable.

## Explore (read-only scout)

Use the Explore agent type. One concern per agent; fan out for breadth.

```
Explore apps/<name> to answer: <question>.
Context: <one or two sentences — why this matters>.
Start at: <entry points if known>.
Do NOT propose changes. Return: the direct answer first, then key files as
path:line references, then anything surprising. Keep it under ~400 words.
```

## Implement (cook)

general-purpose agent. One unit of work per dispatch.

```
Work in apps/<name> (a standalone git repo at apps/<name>).
Task: <the change, concretely — behavior, not vibes>.
Constraints: <stack, conventions; read apps/<name>/CLAUDE.md first>.
Do NOT touch: <files/areas owned by other agents or out of scope>.
Process: follow superpowers:test-driven-development — failing test, minimal
code, pass. Commit per logical change with conventional messages.
Report: append progress to <brain/plans/NN-slug/reports/task-N.md> as you
finish each part (do not wait until the end), then return: what changed,
what you verified (commands + output), what remains.
```

For parallel cooks on one app: give each `isolation: worktree` and disjoint
"Do NOT touch" sets; merge their branches one at a time afterward, running
the app's tests between merges.

## Review (refuter)

Independent agent — never the implementer.

```
Review the diff in apps/<name> (<rev range or worktree path>). Your job is
to REFUTE that it is correct, complete, and scoped — not to approve it.
Hunt specifically for: broken edge cases, missing or vacuous tests, scope
creep, violations of <app conventions / the brain principles relevant here>.
For each finding: severity, file:line, why it is wrong, the smallest fix.
If you cannot refute it, say so explicitly and list what you checked.
```

## Verify (prove-it-works pass)

```
In apps/<name>, run: <test/build/run commands>.
Report the exact commands and the full relevant output. If anything fails,
capture the failure verbatim and stop — do NOT fix it.
```
