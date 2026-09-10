# Development contract

Apply these rules with the root and app `AGENTS.md`. The app's
`failed-test.md` is the approved test plan; `spec.md` is human-owned.
The app's command lines and `Skills:` select its stack-specific checks.

## Approval and scope

Draft tests may be proposed and probed before approval. A RED probe proves
that a candidate fails; it does not prove its expectation is correct.
The human reviews the specification, tests, and required test support.
Record approval with the harness before implementation. Do not edit the
approved plan or baseline to accommodate an implementation. New defects
or incorrect tests need a separate proposal and human approval.

## One verified entry at a time

1. Read the current approved entry and only the source context needed for it.
2. The runtime adds its test verbatim, preserving approved headers and
   existing support, and observes RED. Environment errors are not proof of
   missing behavior. An already passing entry gets an explicit ALREADY GREEN
   receipt and a verified test-only checkpoint without an implementation call.
   An impossible approved test requires human diagnosis. Missing Go symbols
   may be classified as build RED only under the explicit approval exception
   documented in the runtime reference.
3. The worker implements the smallest coherent source change that satisfies
   this entry. It does not edit tests, the plan, or acceptance commands, and
   does not commit or select a second entry.
4. The runtime verifies protected inputs and Git state, then runs the full
   declared suite and required hygiene checks. Focused development tests do
   not replace this checkpoint.
5. Only after validation does the runtime check the entry and commit its
   behavioral change. Worker reports are evidence to inspect, not authority
   to advance. Report the behavior, verification, and unresolved limitations.
6. After the final gate, complete an independent review in a separate
   context, bound to the resulting revision. Findings or unavailable review
   leave completion pending. Request structural refactoring as a separate
   task after the feature, with separate verified structural commits.

The boundary is a verified entry, not the lifetime of a provider session.
The runner currently defaults to fresh worker sessions. Do not skip a
checkpoint to save a session, or claim session reuse is implemented.

## Implementation and commits

Use clear names, explicit dependencies, small cohesive functions, and the
simplest design that satisfies the approved behavior. Keep changes scoped
to the current entry; defer unrelated cleanup and speculative abstractions.
Preserve every interface referenced by approved tests.

The runtime commits each verified behavioral checkpoint. For separately
authorized refactoring, commit structural changes with `refactor:` messages
and verify before and after. Do not mix behavioral and structural changes.
Do not alter tests, fixtures, or the declared acceptance commands to obtain
a pass. Benchmark relevant hot-path changes when the app declares `Bench:`;
report measured regressions rather than hiding them.

## Failure and handoff

Inspect the actual failure before retrying. Keep diagnostics and workspace
state available for recovery. A worker result alone never establishes
completion. A defect outside the approved entries is recorded as a draft,
with a suitable regression test (API-level and minimal reproduction when
both add evidence); preserve the approved inputs until the human authorizes
a replacement. Continue independent authorized work where possible.

These rules adapt Kent Beck's TDD and Tidy First practices to Sobaya's
human-approved test contract; they are not a verbatim upstream document.
