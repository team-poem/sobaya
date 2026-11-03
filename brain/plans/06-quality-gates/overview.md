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
  Open options, recorded 2026-11-03:
  1. Prose only (this branch). Bash-only, nothing enforced.
  2. `gate.sh` runs the tools (branch `claude/gate-enforce`). Strongest, but
     every machine running the gate needs Python and tree-sitter, and a run
     may take up to an hour.
  3. The agent runs the tools and `gate.sh` reads `.metrics/*.edn` with jq.
     Bash-only, but needs proof the metrics match the current code.
- [x] Option 2 built on `claude/gate-enforce`, not merged. Opt-in per app with
  `- Quality: required`, exception list `.sobaya-equivalent-mutants`, CRAP
  only on changed functions, fails on zero covered sites (a Go checkout whose
  directory name differs from the module path reports every site uncovered
  and exits 0) and when dryer reads no files (it skips `.js`). Known gap:
  "changed" means the diff against `HEAD`, so a gate run after `step.sh`
  commits at GREEN may check nothing. Not yet run against a real Go app.
- [x] Classify the 38 survivors in poem-news-collector: 31 missing scenario
  (about 17 distinct behaviors), 6 equivalent, 1 dead code. A no-survivor gate
  therefore needs an exception list keyed by mutator's outcome key, since its
  text report gives line but not column. Classification is by reading, not by
  applying each mutant.
- [x] Measure helper use. `step.sh` committed in 11 apps, latest 2026-10-23;
  `loop.sh` and `review.sh` have review usage records. Keep them. `restart.sh`
  was never observed but sobaya-mode names it as the recovery for a corrected
  test, so it stays. No installed `sobaya` CLI is in use.
- [x] Collapse `.agents/skills/sobaya` and `tdd` into one `sobaya-mode` skill
  shaped like ub-mode, pointing at pstack principles instead of the copies in
  `brain/principles/`.
