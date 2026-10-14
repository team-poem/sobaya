---
name: tdd
description: "Apply Canon TDD to a Sobaya feature: list scenarios, write one failing test, implement GREEN, optionally refactor, and use learning to choose the next test."
---

# One test at a time

Read `tdd-set/AGENTS.md`, the app contract, and relevant product intent.
Use `failed-test.md` as an evolving list of behavioral scenarios. Select the
next case based on uncertainty and what earlier tests taught you. Concretize
one test only; future entries stay descriptions. Do not ask for exact-test
approval or build a frozen executable batch.

Execute the cycle directly in the app, or use the optional shell helper:

1. Add the selected test and its required imports/setup. For `step.sh`, put
   its body after the next unchecked scenario and a `// file:` header in the
   same section. Checkbox identifiers are bare names such as `TestX` or
   `caseName`. The actual Node test title may be `caseName` or
   `caseName: description`. See the runtime README example.
2. Observe RED for the intended reason. `probe.sh` can help diagnose candidates.
   Environment and syntax failures are not behavioral evidence. Do not pretend
   a test was RED when it already passed.
3. Implement only enough to make it and previous tests pass. The helper
   `step.sh APP` does test insertion, worker execution and verification without
   an approval record; direct work must also inspect real execution results.
4. At GREEN, consider a useful structural improvement, including test code.
   Preserve behavior and assertions, run tests after each change, and commit
   structure separately from behavior. There is no mandatory reviewer gate.
5. Update the scenario list from learning and choose again. At a feature
   boundary apply the outcome/learning pause in the development contract.

Human decisions concern uncertain or changed product expectations. Ordinary
test selection, obvious test mistakes and behavior-preserving refactoring
within the authorized goal do not require renewed permission. Explain test
corrections and re-establish evidence; do not disable tests, remove assertions
or substitute actual values into expected values to manufacture a pass.

The helper protects test inputs only during its active RED-to-GREEN attempt.
After a failed attempt, inspect diagnostics and use `--resume` for implementation
recovery. A test correction needs `restart.sh APP` to archive that attempt,
preserve edits, restore a GREEN starting point, and measure the corrected test
afresh. Existing frozen batches use `migrate.sh APP` at a clean, inactive boundary; future test code
is retained in an archive and converted to scenario descriptions.

When a detailed human explanation is useful or requested, use the optional
[source-and-rationale view](references/human-review.md). It preserves the
presented source and checks range coverage; it does not impose test approval
or freeze later changes. Update the view when explaining changed code.
