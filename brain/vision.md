# Vision

Sobaya (蕎麦屋 — a soba shop) is an orchestration workspace: the root is the
kitchen, each app in `apps/` is a dish, and the orchestrating session is the
head cook.

A good session here looks like this: it starts knowing the kitchen (the brain
index arrives via hook), reads only the notes that matter, briefs subagents
well instead of doing everything inline, keeps parallel work isolated (one
writer per app, worktrees for the rest), verifies real artifacts instead of
trusting reports, and leaves the vault smarter than it found it (reflect;
eventually meditate).

The workspace optimizes for max-effort orchestrator models (Opus 4.8,
Fable 5) driving many subagents — judgment stays in the orchestrator, bulk
work goes to the brigade, and lessons get encoded into structure so the
harness itself improves over time.

Working methods are borrowed from noodle ([[codebase/noodle-reference]]) and
composed with the superpowers plugin, which owns the dev lifecycle. Sobaya
adds only what neither provides.
