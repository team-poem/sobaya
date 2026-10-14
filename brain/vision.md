# Vision

Sobaya is an engineering workspace: the root is the kitchen, each independent
app is a dish, and the orchestrator is responsible for completing the order.

The human owns product intent. Agents use Canon TDD: list scenarios, write
one failing test, implement GREEN, then optionally refactor. Tests and future
scenarios evolve from learning without exact-code approval or a permanent
frozen baseline. Actual execution evidence matters; independent review is
optional when useful, not a mandatory permission to continue.

A good session reads only relevant knowledge, chooses delegation for useful
independent work, isolates writers, verifies artifacts, and finishes the
authorized task. It records durable lessons without creating duplicate rules.
The default worker policy is a practical choice, not a model hierarchy that
determines permission to maintain the harness.

Development alternates between small behavioral increments and recovering
room for change. Keep scenarios flexible, concretize one next test, and use
GREEN to consider useful tidying. At feature boundaries, review observed
outcomes and learning before choosing more work. No useful refactor or new
durable note is a valid result; feedback matters more than producing process
artifacts. The development contract distinguishes the orchestrator's judgment
from the runtime transitions that are actually implemented.

`tdd-set/` owns the development cycle and optional shell execution helpers. The shared `AGENTS.md` contract,
focused skills, and small runtime keep policy explicit. Future efficiency
work may reuse sessions without weakening per-entry validation; current
fresh sessions are the safe default. See [[codebase/noodle-reference]] for
historical inspiration and the runtime reference for current commands.
