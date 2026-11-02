---
name: sobaya-mode
description: >
  Sobaya's working mode on top of pstack. Use for any change to a Sobaya app
  or the harness, for choosing the next test, and for delegation or worktree
  decisions. Every change follows Make it Work, then Make it Right, then
  Practice.
---

# sobaya-mode

Read the root `AGENTS.md`, the app's `AGENTS.md` and `tdd-set/AGENTS.md`
first. `tdd-set/AGENTS.md` owns the cycle and the quality checks. This skill
adds only the decisions they leave open. A bold name is a pstack principle
skill, `principle-<name>`. Read its leaf before you apply it.

Every change:
* First Make it Work.
* Then Make it Right.
* Follow Practice.

# Make it Work

## Preflight

* Read `brain/index.md`, the notes relevant to the task, `brain/apps.md` when present, and the target repo's Git status.
* Before implementing, read the app's `spec.md`, `failed-test.md` and active state through `tdd-set/bin/status.sh APP` and `doctor.sh APP`.
* State the objective, the authorized scope, the acceptance evidence and the next bounded unit.

## Canon TDD

* Follow Canon TDD in `tdd-set/AGENTS.md`, one test at a time.
* The human owns `spec.md`. Never edit it. Ask only when expected product behavior is ambiguous or would change.
* `failed-test.md` is the scenario list. Pick the next scenario by what is most uncertain and what the last test taught you. Write only that test; later entries stay prose.
* Never ask for approval of an exact test and never write a frozen batch.
* For the `step.sh` input format, see "Scenario list and the next test" in `tdd-set/README.md`.
* After a failed `step.sh` attempt, `--resume` recovers the implementation. A corrected test needs `restart.sh APP` first.

## Principles

* Before writing logic, **foundational-thinking**.
* Sizing the diff, **laziness-protocol**. Before adding anything, **subtract-before-you-add**.
* A new requirement on an old design, **redesign-from-first-principles**.
* Two failed fixes sharing one premise, **attack-the-premise**.

# Make it Right

## Quality checks

* Run `mutator`, `crapper` and `dryer` at the points and thresholds in `tdd-set/AGENTS.md` (Canon TDD step 4, Quality checks, Between features).
* Every test you write or keep passes **test-behavior-not-implementation**.
* An unexpected RED or a surviving mutant is diagnosed per **fix-root-causes** before any edit.

## Refactoring

* Refactor only at GREEN, source and tests alike, keeping behavior and assertions.
* Run the full suite after each small change.
* Commit structure apart from behavior.
* Never weaken a test, drop an assertion or copy actual output into an expectation to reach GREEN.

# Practice

## Worktree per writer

* One writer per checkout. Parallel mutation gets its own worktree. Integrate one at a time and verify between merges. See **separate-before-serializing-shared-state**.
* Delegate only bounded, independent work whose breadth, risk or need for an independent read pays for the extra context. File count alone is not a reason.
* Each brief names the absolute checkout, the scope, the protected inputs, the expected artifact and the verification. During a RED-to-GREEN attempt the protected inputs are `spec.md`, the selected test, existing tests and support, and the plan.
* Exploration returns conclusions with `path:line` evidence, not file dumps. See **guard-the-context-window**.
* The policy in `tdd-set/policies/` fixes workers, call budgets and fallback. Never switch models or relax acceptance silently.
* Use explicit working directories or `git -C`.

## Evidence before progress

* A worker report, a commit or a checked box is not proof. Read the diff and the real test output before advancing. See **prove-it-works**.
* Diagnose a failed delegation before you retry it, rebrief it or change models.
* Never claim GREEN when the tests could not run.
* Carry authorized, reversible work through verification without asking again. Present a product decision concretely and keep working on what it does not affect. See **never-block-on-the-human**.

## Brain and reflect

* App plans live in the app repo. Cross-app and harness plans live in `brain/plans/`.
* Persist progress before a long or interruptible handoff.
* After substantial verified work, run the `reflect` skill and keep only durable learnings. No change is a valid result.
* Never hand-edit `brain/index.md`. Run `scripts/brain-index.sh`.

## Review view

* When someone asks for a line-by-line explanation of a test, follow `references/human-review.md`. It is not an approval gate.
