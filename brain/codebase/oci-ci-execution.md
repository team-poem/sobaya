# OCI CI execution

The public `ci / verify` job relays trusted same-repository pull requests, `main`
pushes, and manual runs to the private `team-poem/oci-ci` executor. It waits for the
exact dispatched run and mirrors its result. The private executor checks source
repository, branch, pull-request head, and tested merge SHA before checkout, then
runs `bash tests/run.sh`, `bash scripts/brain-index.sh . --check`, and
`bash scripts/workspace-check.sh .` on Ubuntu ARM64.

Fork and Dependabot pull requests run those same checks on GitHub-hosted runners and receive no
executor credential. No OCI runner is registered to public Sobaya, so a fork
cannot select the permanent server by modifying workflow labels. Workflow `if`
conditions alone would not provide that boundary.

The harness remains Bash 3.2, jq, Git, and standard Unix tools. Node runs the
existing JavaScript test fixtures and the private executor's CI relay; Go runs
existing Go fixtures. No new harness runtime or acceptance criteria are introduced.
The workflow pins its private relay checkout to a reviewed commit. Its GitHub App
token is scoped to the executor, with Contents write for dispatch and Actions read
for polling; checkout does not retain credentials.

Host setup, resource management, and cleanup are documented in the private
executor repository. The public relay job has a 60-minute timeout, and its polling
script waits up to 55 minutes; waiting for execution counts toward these limits.
CI does not deploy applications.

Evidence belongs in the change's actual Actions runs: configuration and local
validation alone do not demonstrate that the registered runner executed a job.
See [[principles/prove-it-works]] and [[codebase/runtime-language-is-a-user-constraint]].
