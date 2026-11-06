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
- [x] Decide whether the harness may invoke the Python tools. Decided
  2026-11-06: no. The agent runs them and `gate.sh` reads `.metrics/*.edn`
  with awk (the tools write EDN only, so jq cannot read it). Root `AGENTS.md`
  keeps the Bash-only rule. The option where `gate.sh` runs the tools stays on
  the unmerged branch `claude/gate-enforce` for reference.
- [x] `gate.sh` reads the results. Opt-in per app with `- Quality: required`.
  A result missing or older than a changed file (mtime) fails and prints the
  rerun command. Survivors and CRAP 10 or more count only in changed
  functions; listed equivalent mutants in `.sobaya-equivalent-mutants` pass.
  Changes are measured from the cycle base: `HEAD`, the parent of `step.sh`'s
  checkpoint while `HEAD` is that checkpoint, or `SOBAYA_QUALITY_BASE`. This
  closes the gap where a gate after the GREEN commit checked nothing:
  `mutator --changed` and `crapper --changed` read `git status`
  (mutator `cli.py` `_changed_files`).
- [x] Run against a real Go app, a clone of `poem-news-collector` with one new
  function. Observed: missing results fail; old `Normalize` survivors no
  longer block an unrelated change; after a `step.sh`-style commit the gate
  still caught the new function's survivor; the full cycle passed once the
  equivalent mutant was listed. Found and fixed on the way: crapper scores
  test files named on its command line (test functions at CRAP 72), and
  `&&` after mutator skipped crapper and dryer because mutator exits 3 on a
  survivor. Unexplained: the first run recorded the equivalent
  `ClampDisplay` mutant `>` to `>=` as killed; a rerun said survived.
- [x] Cross-model review (Codex) of the diff. Fixed: a fresh snapshot of one
  file no longer vouches for another changed file, and non-ASCII paths are no
  longer quoted by Git into false stale reports. Kept as documented limits:
  empty or forged result files pass the freshness check, and a CRAP entry
  mutator does not locate counts as changed, so crapper must run on the
  changed files only.
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
