# Install flow draft validation

This is pre-approval test/support evidence, not implementation acceptance.
The exact new installer, connection and bump tests have not been approved.
No production runtime, existing test, helper, fixture, approval record or
acceptance command has been changed in this tranche.

## Read-only architecture evidence

An independent exploration exported the existing runtime without .git and
ran its unchanged test_red_green_checkpoint_and_baseline_survive_replay case:
real Node/Git, deterministic worker, approval through checkpoint and review
passed. Existing doctor failed because it treated the runtime as a Git
workspace. Adapt integration/diagnostics; do not replace acceptance rules.

The existing package contract includes tdd-set/lib recursively, so a standalone
installer there can ship without changing approved payload tests or adding a
third packer output. Tar append probes retained the real Git archive commit
marker for duplicate, hardlink, FIFO and traversal fixtures. BSD branches were
executed on macOS bsdtar; the GNU branches require validation on a GNU host.

## Draft repairs before approval

Independent review found and prompted these corrections:

- Empty Bash arrays under set -u fail on Bash 3.2. Mode helpers now branch
  explicitly rather than expanding an empty APP_ARGS array.
- The approved fixture plan header must also occur in its existing test file.
  The exact // file header is present before running the materializer/gate.
- Pin-tampering workers now first implement the correct function. Otherwise
  ordinary RED could falsely look like pin-protection evidence.
- Preserve workspace AGENTS.md as well as the app's contract files.
- Instrument the copied real contract_suite call, not only the configuration
  read by a test, to identify candidate-runtime validation during bump.
- Original commit-msg must receive a real message path and read its content;
  a nonempty log prefix alone cannot prove argv forwarding.
- Skip fixture commits with no staged diff: a valid project connection may
  leave the app's tracked files entirely unchanged.
- Identify each app by its own path, rather than counting generic suite events.
- Snapshot shared Git config and the main worktree config: an explicit main
  override could conceal an accidental shared setting change.
- Successful bump must run lint; separate suite/lint failures must both restore
  the original pins and approval state.

Support probes in temporary copies ran existing approve/loop/gate for both
modes and verified baseline, state version 1, two calls and review HEAD.
The linked-worktree original-hook fixture ran successfully. The real second
app's candidate suite returned 10 with secondAppGuard as the failed named test
when its failure switch was set. These probes used draft support with the old
runtime, not the absent management/installation implementation.

## Approval boundary

The final source SHA-256 is
`b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0`.
Bash 3.2 syntax passed. The missing installer reports NOT PROBED with exit 2
before named tests execute. All twelve entries rejected an always-successful
non-installing control at the installed-identity assertion (exit 1 overall).
Neither a missing command nor control failures are feature RED evidence.

Independent re-review reported no remaining findings at that exact hash.
Its diagnostic non-installing probe generated all eight unsafe archive shapes
and confirmed the intended member shapes, hashes and embedded Git identities.
This is fixture-support evidence only, not acceptance of a new implementation.

The Korean review includes all 511 source lines and 446 added explanation
lines. Removing only those added `# ┎` / `// ┎` lines from the four-backtick
code fence recovers the original bytes and hash. Semantic review narrowed
comments about Git commit markers, prompt presence, completion markers,
unstaged tracked differences and per-app candidate-runtime observations to
what the adjacent assertions actually prove. The executable was not changed.

Automatic approval review rejected the proposed approval/materialization
commit after the human's request to implement: the exact new test inputs had
not yet been shown for human review. The command did not execute; no approved
test file, approval record or production implementation was created. Publish
the completed Korean review packet before requesting exact-input approval.

After explicit approval, materialize the reviewed bytes without explanations,
record root-maintenance approval, implement one named entry and full-suite
checkpoint at a time, and perform revision-bound independent completion review.

## Reflection

Brain: task-specific preparation and verification retained in this plan.
Skills: unchanged; the existing exact-input review rule already applies.
Structural: draft fixture assertions encode the corrected evidence gaps.
Todos: remaining release compatibility/performance work stays in overview.md.
