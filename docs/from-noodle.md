# From noodle to Sobaya

Sobaya borrowed workspace practices from [poteto/noodle](https://github.com/poteto/noodle),
a Go runtime that schedules model workers through file-based work orders.
This is a source mapping, not a claim of runtime compatibility.

| Source idea | Current Sobaya adaptation |
|---|---|
| Work orders and staged execution | Human-approved `failed-test.md`, one verified entry, final gate and independent review |
| Context brief | Relevant brain notes, app status, acceptance state, and a bounded work brief |
| Worker processes | Explicit worker policies; default Codex/Astra and a generic command adapter |
| Deliverable differs from process exit | Runtime verifies protected inputs, tests, and checkpoints independently of worker reports |
| Recovery and adoption | Recorded approval and progress; inspect preserved state before explicit resume |
| Worktree isolation | One writer per checkout, isolated parallel changes, sequential verified integration |
| Diagnosis before retry | Structured diagnostic handoff; no unconfigured model upgrade |
| Brain, reflect, meditate | Durable memory, selective loading, evidence-based maintenance |
| Event-driven conveniences | Optional host integration; explicit runtime and workspace checks remain usable directly |

Sobaya does not adopt noodle's daemon, scheduler, or web UI. Delegation is
chosen for independent useful work and review risk, rather than for every
file change. Historical migration notes and archived plans describe earlier
provider-specific hooks; they are not instructions for the current runtime.
