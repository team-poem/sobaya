# Sobaya

Sobaya is a failing-test-first engineering workspace. The human owns the
specification and approves the tests. Workers implement one approved entry
at a time; the harness validates the result before advancing.

## Shared contract

- **Implementation language:** the harness uses Bash 3.2, jq, Git, and
  standard Unix tools. A different runtime language requires explicit user
  approval; architecture approval alone does not authorize that change.
  App source languages remain app-specific.
- **Canonical instructions:** this `AGENTS.md`, the app's `AGENTS.md`, and
  `tdd-set/AGENTS.md`. Provider adapters do not redefine acceptance rules.
- **Human-owned inputs:** never edit `spec.md`. Agent-generated tests are
  drafts until the human approves them. Preserve the approved plan, test
  bodies, headers, existing tests, helpers, and fixtures. A wrong test
  requires a human-reviewed replacement baseline; do not weaken it to pass.
- **Evidence before progress:** a worker's exit code, report, commit, or
  checked box is not acceptance. Use the harness checkpoint, final gate, and independent completion review.
  Run the full declared suite at validated checkpoints. Never claim green
  when tests could not run.
- **Authorized completion:** carry authorized, reversible work through
  implementation and verification without asking for repeated permission.
  Ask when new authority or a human decision is required, including changed
  acceptance criteria. Diagnose failures before retrying or changing models.
- **Role-neutral maintenance:** any authorized agent may maintain the root
  harness. Model names and commit trailers do not grant authority. Preserve
  user changes, stay within the task's scope, and verify harness changes.
- **One writer per checkout:** use separate worktrees for parallel mutation;
  integrate sequentially and verify. Delegate only bounded, independent work
  whose risk, breadth, or need for independent review justifies the overhead.

## Workspace

Apps live directly at `apps/<name>`, each in its own Git repository. Do not
nest another project or workspace inside an app. `references/` holds source
references. The root owns the harness, skills, documentation, and `brain/`.
App design documents, `spec.md`, and `failed-test.md` belong in the app repo.
Use explicit working directories or `git -C <app>` for repository commands.

Start with the relevant brain notes and the target repository's status.
Read only the context needed for the current decision. For substantial
orchestration, use the `sobaya` skill; for planning, use `tdd`; for the
verified development cycle, read `tdd-set/AGENTS.md`. Runtime commands and
worker policy are described in `tdd-set/README.md`.

## Memory and language

`brain/` is an Obsidian-compatible vault: one topic per file. Read
`brain/index.md` when the index has not already been supplied. Use `reflect`
after substantial work or a correction, and `meditate` only when justified.
Never hand-edit the generated `brain/index.md`. Plan directories maintain
`brain/plans/index.md`; archive completed plans under `brain/archive/plans/`.
`brain/apps.md` is clone-local and gitignored; its template is
`brain/apps.template.md`. Persist useful progress before a long handoff.

Agent-facing instructions and brain notes are English. Keep `README.md`
and its Korean mirror `README.ko.md` aligned. Other human-facing guides
under `docs/` are Korean; historical source mappings may retain their
English mirror. Avoid duplicate instructions and provider-specific copies.
