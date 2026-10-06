# Installed flow implementation evidence

Approved input: b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0.
Both draft and materialized tests remain byte-identical. Tests run with
TMPDIR=/private/tmp so Git/Node canonical paths agree on macOS (the default
/var temporary directory is a symlink). Workers and downloads use the approved
controls; Git, Node, archive validation and existing acceptance gates are real.

## Entry checkpoints

1. install_pins_real_release_and_transport: RED at the installed command's
   explicit unimplemented operation, then GREEN against real tagged archives,
   retained bytes/permissions, consumer preservation, repeat install, and fixed
   HTTPS transport arguments. The complete existing tests/run.sh passed using
   actual Go, Node and the local Vitest dependency tree. Independent focused
   review found missing-parent dotdot containment and missing-launcher holes;
   both were fixed and directly reprobed. Safety validation is part of this
   coherent installer; later rejection entries may already be green.

Entries below record subsequent acceptance. No v1 release or PR merge performed.

2. install_rejects_identity_and_unsafe_payload: ALREADY GREEN from the safe
   extraction implemented for entry 1. Wrong manifest/tuple/hash/commit and all
   eight malformed payload shapes rejected. Independent probes additionally
   found invalid retained metadata and missing launcher backing; both were
   repaired, reprobed, and reviewed without remaining findings. Entries 1–2
   and the complete existing suite passed at this production revision.

3. install_preserves_existing_paths_and_failed_downloads: ALREADY GREEN.
   Existing directories/files/live and dangling symlinks, contained stores,
   failed partial downloads, conflicting identity and tampered executables all
   rejected without changing preserved state. No production bytes changed
   after checkpoint 2; its just-completed full-suite evidence applies to this
   identical runtime, with entry 3 additionally executed before this checkpoint.

4. init_connects_both_modes_without_rewriting_contracts: RED at the old
   config-only CLI, then GREEN for both modes. Existing instructions, spec,
   plan, nested consumer layout and project brain are preserved. Repeated init
   is byte/permission/path stable and creates no approval. Entries 1–4 and the
   complete existing suite passed. Independent review found metadata-parent
   symlink and late instruction-conflict checks; preflight now refuses these
   before publication. Seven supplemental conflict probes preserved the whole
   consumer and outside targets; review reported no remaining init findings.

5. connected_hooks_preserve_original_behavior: RED because lint was bypassed
   by the untouched old hook path, then GREEN with original pre-commit first,
   Sobaya hygiene second, preserved commit-msg argv, original files and links.
   Entries 1–5 and the complete legacy suite passed. Focused review prompted
   rejection of unsupported executable hooks and shared multi-worktree hook
   configuration without worktreeConfig. Wrappers also respect later disabling
   of original executable hooks. Final independent completion review remains
   required after all entries; no acceptance criteria changed.

6. connection_keeps_linked_worktree_hooks_isolated: ALREADY GREEN from the
   explicitly scoped hook configuration in entry 5. Actual commits used each
   worktree's original hook; only the connected one ran Sobaya hygiene. Shared
   and main-worktree Git configs were unchanged. No production change after
   checkpoint 5, so its full-suite evidence applies to this identical runtime.
   Independent hook review additionally passed nine preservation/forwarding
   probes, including argv, binary stdin, cwd, environment, streams and status.

7. installed_modes_execute_approved_cycle: RED at missing installed doctor,
   then GREEN for both modes through actual approval, materialization, RED,
   GREEN, checkpoint, final gate and independent-review state (two fixture
   worker calls). Entries 1–7 plus the full existing suite passed. Focused
   independent probes verified a V1 launcher dispatching the exact V2 runtime,
   reapproval/status/usage/gate preservation and no missing/altered fallback.
   A Bash 3.2 local-variable EXIT-trap unwind bug was fixed and cleanup reprobed.
   Installed boundary permission checks now use one stat per path rather than
   twelve find+sed pairs, preserving all twelve permission bits and identical
   comparison output. One 80-path local sample measured 2.38s versus 0.77s per
   tree walk; this is limited mechanical evidence, not model or v0.9 parity.

8. dispatch_rejects_pin_drift_and_worker_mutation: RED at a late hook failure
   instead of protected-input rejection, then GREEN with workspace pins in
   operation snapshots. Entries 1–8 and the full existing suite passed; final
   focused 7–8 checks passed after the gate selection guard. Independent probes
   covered project pins outside the app, mutation at lock acquisition, suite
   mutation during gate/review, and mutation while taking the gate's initial
   stamp. Each rejected without advancing approval; the last race stopped
   before any suite or worker execution. No remaining scoped review finding.

9. sync_uses_reviewed_lock_without_repinning: RED at the missing sync command,
   then GREEN installing the reviewed tuple into a second store. A wrong
   archive fails its hash check without publication; both paths preserve the
   entire consumer, including connection and approval metadata. Entries 1–9,
   the full existing suite, Bash 3.2 syntax and ShellCheck error checks passed.

10. bump_validates_candidate_and_preserves_approval: RED at the missing bump
    command, then GREEN with an actual completed dependency-mode cycle and
    candidate suite/hygiene. Entries 1–10 and the full existing suite passed.
    Focused review found approval metadata mutation surviving rejection and
    an extra background subshell allowing validation to outlive cancellation.
    External backups now restore protected metadata without replacing the live
    lock inode, and the tracked child execs the validator directly. The final
    approved success case passed after both repairs. Supplemental probes verify
    lock contention, stale-worker-record preservation, restored calls and full
    metadata equality, and no delayed validation write after cancellation.

11. bump_failure_and_active_entry_keep_previous_pin: ALREADY GREEN from the
    transaction and active-entry guard in entry 10. Real candidate-suite and
    lint failures restore both documents and all approval metadata exactly;
    an interrupted protected-input entry rejects bump before changing state.
    No runtime bytes changed after checkpoint 10; its full-suite evidence and
    final focused repair probes apply to this unchanged implementation.

12. project_bump_checks_every_connected_app: RED at the explicit unsupported
    project bump, then GREEN after validating and locking every registered
    app. Both apps execute the candidate's real suite; second-app failure
    restores the preceding pin. Workspace metadata participates in preservation
    and locking alongside app metadata. The unchanged twelve-case suite is
    now registered additively in tests/run.sh.

## Final integration and review

The complete integrated command passed on macOS with Bash 3.2:

```
TMPDIR=/private/tmp \
SOBAYA_TEST_VITEST_ROOT=/Users/kangminkim/lunch/sobaya/apps/bdad-mentor-match \
/bin/bash tests/run.sh
```

This includes all twelve installed-flow entries, existing contract/runner/tools,
configuration/release tests, and next/probe/verbatim-gate regressions. Log:
/tmp/sobaya-install-final-integrated.log. Real Go, Node and local Vitest ran;
workers and acquisition were controlled fixtures, with no provider/network call
or forbidden interpreter. Bash syntax, ShellCheck error checks, guide command
syntax and git diff --check also passed.

Independent completion review found a compatibility mismatch: config check
accepts mixed-case hexadecimal identities but installed comparisons did not.
Internal comparison now normalizes only hexadecimal case, preserving reviewed
lock bytes. Direct config/sync/status probes pass with an uppercase lock.
Another probe showed a successful candidate could disable hooks through Git
config. Bump now snapshots and restores common config and config.worktree,
including original absence and permissions. Both normal and actual linked
worktree mutation probes reject and restore the original selected hooks.

Draft and materialized source SHA-256 remain
b27ddd26f4d6e13f8a11d11d5df2cab5278547445082e5462de5797d580080c0.
The annotated view remains
dece32c30ea8a0893e81e21284308601282d9daf994c6bdfbc28b845a1ff8253;
removing only inserted review explanation lines recovers the source exactly.
No existing test body, spec or acceptance command was edited.

Independent completion review found no remaining actionable findings at
ccf08e4c199ea366b7b05bd57ba9c50361122870. The reviewer independently read the
complete integrated log, checked the clean tree and unchanged approval hash,
reprobed both identity/configuration repairs, and reviewed the aligned guides.
This receipt is a documentation-only follow-up to that reviewed checkpoint.
Actual Linux flock was unavailable on this host. Live published-asset tests,
real v0.9/v1/v0.9 compatibility, crash recovery and model performance comparison
remain release work, not claims established by these local fixtures.
