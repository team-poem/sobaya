# 06 Quality gates replace judgment at GREEN

Sobaya's cycle left three decisions to the agent's judgment: whether a test
actually pins behavior, whether to refactor, and whether duplication has piled
up. Approval gates tried to cover the first and were retired on 2026-10-14.
This plan replaces those judgments with unclebob's measuring tools, following
ub-mode's "Then Make it Right" section, and shrinks Sobaya toward one mode
skill on top of pstack.

## Done when

An agent working in a Go or Node app runs `mutator --changed` and `crapper` at
every GREEN and `dryer` plus a full `mutator` run at each feature boundary,
and acts on the result without asking the human. The harness suite stays
green and Bash-only.

## Units

- [x] Baseline on `apps/poem-news-collector` (scratch copy, app untouched).
  Mutation 174 killed, 38 survived, 16 uncovered of 228 sites (82.1%).
  7 of 40 functions at CRAP 10 or more, worst `listCollections` 30.0 at 0%
  coverage. Dryer found no duplicate candidates.
- [x] Remove the retired approval surface: `tdd-set/bin/approve.sh`, the
  `approve` dispatch and diagnostic, `tests/archive/approval-v1/` and three
  unreferenced approval-era review drafts under `docs/`.
- [x] Put the three checks into `tdd-set/AGENTS.md` at GREEN and between
  features, as app-level checks the agent runs.
- [ ] Decide whether the harness may invoke the Python tools. Root
  `AGENTS.md` requires explicit user approval for a non-Bash runtime, and
  `tests/run.sh` fails any harness call to python. Until then the checks are
  prose, which nothing enforces.
- [ ] If approved, `gate.sh` runs the three tools and fails on a survivor,
  CRAP 10 or more on a changed function, or a run with zero covered sites.
  The zero-coverage case is a measured trap: a Go checkout whose directory
  name differs from the module path reports every site uncovered and exits 0.
- [ ] Classify the 38 survivors in poem-news-collector into missing scenario,
  dead code and equivalent mutant, to see how much work the gate creates per
  app before turning it on everywhere.
- [ ] Measure whether `step.sh` and `loop.sh` are still used. If not, delete
  them and most of `tdd-set/lib/runner.sh`.
- [ ] Collapse `.agents/skills/sobaya` and `tdd` into one `sobaya-mode` skill
  shaped like ub-mode, pointing at pstack principles instead of the copies in
  `brain/principles/`.
