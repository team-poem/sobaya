---
name: tdd
description: Draft and probe a feature's tests before human approval, then apply Sobaya's approved-entry workflow. Use for test-first planning, explicit tdd requests, or initial feature setup.
---

# Plan and approval

`tdd-set/AGENTS.md` owns the development cycle. The app's `spec.md` is the
human's goal; `failed-test.md` contains the test plan. Use ordinary CLI
commands from the Sobaya root; no provider slash-command support is needed.

## Draft before implementation

1. Read the specification and relevant app code. If the specification is
   missing or still a template, ask the human for the intended behavior.
2. Split the behavior into small, named increments. Enumerate meaningful
   normal, empty, boundary, duplicate, ordering, and failure cases. Prefer
   distinct behavioral evidence over a large count of redundant cases.
3. Probe candidate tests with `tdd-set/bin/probe.sh`. Diagnose each RED:
   a missing intended symbol can be useful evidence, but missing imports,
   unavailable dependencies, and broken tooling are not behavioral evidence.
   Record probe results and limitations with the draft.
4. Show the complete draft using the human review view below, including
   required support and any uncertain expectations.
   Agent-generated tests remain drafts until explicitly approved. If that
   approval already exists for the exact inputs, do not ask again.
5. Commit the human-reviewed inputs and use `approve.sh <app>` to record
   their baseline. An agent may record approval only when the human has
   authorized those exact inputs. `--replace` requires explicit approval
   of the changed inputs and baseline; it is not an automatic repair.

Write no implementation code while acceptance criteria are awaiting approval.
A RED result does not prove a test is correct; review expected behavior.

## Draft format and probes

Each entry has `- [ ] TestName — what it proves` and a fenced code block.
Use stable identifiers: Go `TestX`; Node titles beginning with an identifier,
for example `test("loginRejectsEmptyEmail: ...", ...)`.

For Go, probe a complete function with its required import block:
`probe.sh apps/<name>/<package-dir> -`, snippet on stdin. The probe supplies
the package declaration. Record the test function in the plan and ensure
its required imports can be added without rewriting protected support.

For Node, create one section header with a `// file:` target relative to
the app root, imports, and shared constants. Pass that header as the third
argument to `probe.sh apps/<name>/<test-dir> - <header-file>`; pass one
complete test block on stdin. The approved header and target are part of
acceptance, not implementation choices.

Do not add a GREEN candidate as a new missing behavior without resolving
why it is already satisfied. Do not silently repair a human test.

## Human review view

Apply this presentation to every initial draft, revised draft, and replacement
proposal during a TDD run. Keep executable headers and test bodies in the plan
without the added review explanations. Necessary source comments remain part
of the executable inputs and are protected on approval.

Create the human-facing copy from those exact executable blocks. Label it
"검토용 — 설명 주석은 실행 코드에 포함되지 않음" and identify the plan entry
and destination file. Insert standalone Korean explanation comments marked
with `┎` immediately above each meaningful code line: test declaration, inputs,
setup, actions, branches, and assertions. Explain multiline expressions at their meaningful
parts; blank lines and closing delimiters do not need explanations. Explain
behavior and concrete expectations rather than translating syntax. State what
fixtures, mocks, clocks, and helpers assume or bypass. Include shared headers
and required support in the review, explaining shared code once before its
entries and pointing to it from dependent tests. Use the language's comment
syntax (`// ┎ 설명` for Go/JavaScript, `# ┎ 설명` for Bash), keeping the marker
aligned with the following code line's indentation.

Preserve all original code, source comments, whitespace, and ordering in this
copy; do not abbreviate, rename, reformat, or replace code with pseudocode.
Before showing it, compare it with the executable input: removing only the
newly inserted explanation lines must recover the exact original block.
Check that each explanation describes what the adjacent code actually does
or verifies; a response-status assertion does not prove a visible UI message.
Surface unresolved expectations for the human instead of asserting them as
settled requirements.

Deliver this view in the conversation or a separate review document, never as
extra executable fences in `failed-test.md`. Probe, approve, and materialize
only the underlying executable inputs. Approval is of the code shown through
this view; do not strip comments from or otherwise rewrite approved inputs.
Any subsequent code change requires an updated view and renewed approval.

For a replacement, explain why it is needed and which expectations change,
then show the complete proposed blocks with the same annotations. Keep the
current approved baseline intact until the human approves the replacement.
An implementation or environment failure alone does not require test changes
or another approval. See the Korean presentation example in
[`docs/guide.md`](../../../docs/guide.md#주석으로-테스트-검토하기).

## After approval

Use `next.sh <app>` for the current entry, `step.sh <app>` for one worker
step, or `loop.sh <app>` to continue through validated entries and review.
The runtime inserts the test, measures RED, verifies GREEN, checks the box,
and commits. The worker implements source only and does not commit. Load only
the current entry and needed source context; read the full plan when
planning or reviewing acceptance requires it.

Preserve approved code and headers verbatim, existing tests, helpers, and
fixtures. An unexpected defect or impossible assertion needs a separate
draft proposal and human approval, not an edit to the approved plan.
Only the harness validation authorizes progress. A worker must not move to
another entry merely because its own test command passed.
