# Run one approved implementation step

Provider-neutral task reference. Replace `APP` with `apps/<name>`; this
file does not require a host slash-command registration.

Read `tdd-set/AGENTS.md` and the app contract. Inspect status, then use
`tdd-set/bin/step.sh APP` with the selected policy. The runtime materializes
the test, measures RED, validates GREEN, checks the entry, and commits.
Workers implement source only. Diagnose failures; do not edit approved
inputs or silently select another model. Report the verified checkpoint.
