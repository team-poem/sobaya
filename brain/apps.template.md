# Apps

One line per app. Copy this file to brain/apps.md (gitignored) in each clone. Add a row after `tdd-set/bin/install.sh`; keep status current
(scaffolded → active → paused → archived · imported = external/vendor
source dropped into `apps/`, not sobaya-scaffolded).

Apps are per-clone and never pushed to this repo — sobaya is a
harness-only template; each checkout grows its own `apps/`. Whether an
app keeps a local repo or a remote is the app's own choice, so "local
only" below is a fact, not a problem. Only flag a Git cell when a
clone's origin still points at this template repo (push hazard).

| App | Purpose | Stack | Status | Git |
|---|---|---|---|---|
