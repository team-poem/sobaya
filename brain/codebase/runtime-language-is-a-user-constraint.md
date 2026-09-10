# Runtime language is a user constraint

The user approved Sobaya's model-neutral architecture, not a new implementation
language. The September 2026 migration initially introduced a Python coordinator
and test infrastructure without that separate approval. That was an agent scope
error, even though the behavior had tests and the architecture was agreed.

The correction restores the harness to shell: Bash 3.2, jq, Git, and ordinary
Unix tools. Keep app-language fixtures separate from harness implementation.
Do not justify a language change as an incidental implementation detail when
the user's intended maintenance model is a shell harness. Propose a concrete
tradeoff and obtain explicit approval before introducing another runtime.

Preserve behavioral evidence during migrations. Rewriting tests in another
language must retain the existing scenarios and assertions, including failure,
resume, cancellation, integrity, and adapter cases. An interpreter-blocking
aggregate check protects the boundary structurally instead of relying only on
this note. Historical validation results remain historical; report the current
suite's actual result rather than carrying forward an earlier pass count.

Evidence: user correction and full Python-to-shell conversion request during
the 2026-09-10 harness work. See [[model-neutral-checkpoints]] and
[[principles/encode-lessons-in-structure]].
