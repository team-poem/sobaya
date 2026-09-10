# Model-neutral Sobaya harness

Authorized by the user on 2026-09-10: implement the agreed harness redesign,
use Astra primarily with optional other models, and remove legacy
provider-specific instructions and restrictions. This explicitly supersedes
the previous root-maintainer model restriction for this migration.

## Contract

- Human-owned spec and approved test bodies remain immutable during execution.
- Approval, execution, and verification use a stable baseline and exact Git state.
- Model selection changes procedure and task size, never acceptance criteria.
- Default execution uses Codex with Astra; explicitly configured workers can
  use other models/providers without a second instruction tree.
- No automatic paid model calls, external publication, or modifications to
  existing app repositories are needed to implement and verify the harness.
- AGENTS.md is canonical, explicitly confirmed by the user.

## Work

- [x] Map existing interfaces and official/local CLI contracts.
- [x] Add regression coverage for approved-plan mutation, resumed baselines,
  dirty state, execution evidence, malformed inputs, worktrees and locking.
- [x] Implement a small deterministic shared runtime behind existing entry points.
- [x] Add explicit model policies and interchangeable worker adapters with
  structured handoff, bounded execution, and unchanged acceptance criteria.
- [x] Remove legacy instruction/config/command paths and model-exclusive guards.
- [x] Update concise contracts, skills, English/Korean READMEs and Korean guide.
- [x] Run regression and end-to-end fixture tests; get independent refutation.
- [x] Capture verified lessons, archive this plan when complete, report limits.

## Validation

Use temporary Git repositories, actual local test runners and deterministic
worker fixtures. Verify that wrong states fail and valid one-entry transitions
pass. No live paid worker invocation is part of the test suite. Preserve
existing app spec/tests and do not rewrite historical source attribution as
if the new architecture had always existed.

## Progress

Initial checkout is clean at fb4f73f. Earlier audit evidence is available in
the current task's external sobaya-audit artifact directory. Implementation and documentation were reviewed against that evidence and the
user-approved architecture. Independent agents reviewed acceptance, tools, and
runtime/documentation alignment in isolated worktrees; integration was sequential.

Final validation: 91 Python regressions passed with actual Go, Node, and Vitest,
plus 8 shell checks. Root hook activation and explicit workspace/index checks
passed. No live model call or existing app mutation was performed. App-owned
instruction migration was inventoried and awaits the separate scope answer;
actual app worktrees and substantive provider notes were preserved.

See docs/harness-validation.md for the verified scope and limitations.
