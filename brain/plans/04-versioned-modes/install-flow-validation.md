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

No later entry has been accepted yet. No v1 release or PR merge performed.

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
