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
proposal during a TDD run. Show each complete original source block continuously,
then explain its design in Korean outside the code. Identify the plan entry and
destination. Preserve code, comments, whitespace, and order; never insert review
comments, line numbers, or explanations into the code.

Account for every physical line with contiguous, nonoverlapping ranges, including
headers, helpers, fixtures, blank lines, and closing delimiters. Assign blanks and
delimiters to a neighboring range. Grouping setup/action/assertion is optional;
neither grouping nor an importance judgment may omit lines or hide distinct
choices in a generic summary. Explain shared support once and explicitly link
every dependent entry to it. Inventory all required source blocks before review;
line coverage of one block does not establish that the inventory is complete.

For each range, explain what it does, why it is designed that way, the basis of
its values, conditions, mocks, and expectations, and its contribution to the
test's evidence and limits. Distinguish requirements from illustrative choices,
assumptions, and unresolved expectations. Do not invent a rationale or claim
evidence beyond the actual assertions. A response-status check does not prove a
visible UI message.

Read [`references/human-review.md`](references/human-review.md) when preparing
this view: it defines the source inventory, rationale fields, and
`tdd-set/bin/review-view.sh SOURCE NOTES_JSON OUTPUT.md`. The helper creates a
separate Markdown document and checks source identity and complete line coverage;
it cannot judge the rationale or discover omitted source blocks. Deliver the
view in conversation or a separate document, never as extra executable fences
in `failed-test.md`. Probe, approve, and materialize the exact executable inputs;
the runtime never strips comments or reformats them.

For a replacement, state why it is needed and which expectations change, then
show the same complete code and rationale review. Preserve the current approved
plan, tests, and support until the human approves the changed inputs and baseline.
Any subsequent code change needs an updated view and renewed approval; an
implementation or environment failure alone does not. See the Korean example in
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
