---
name: meditate
description: Use after several reflect cycles have accumulated, or on explicit user request — audits the brain vault with subagents, extracts principles from repeated lessons, refines skills, and archives finished work. Expensive; don't run casually.
---

# Meditate

A vault audit. Two subagents examine the vault from different angles; the
orchestrator judges and applies. [[principles/prove-it-works]] applies to
their proposals too — verify claims against the actual files before acting.

## 1. Snapshot

Build a cheap snapshot to paste into both agent prompts:

```sh
find brain -name '*.md' -type f | sort
wc -l brain/*.md brain/*/*.md brain/*/*/*.md 2>/dev/null | tail -25
```

Include the snapshot AND the current `brain/index.md` content.

## 2. Auditor (staleness pass)

Dispatch one general-purpose agent:

```
Audit the Sobaya brain vault at <absolute path>/brain.
Snapshot: <paste snapshot + index>.
Read every codebase note and principle, then propose, each with a reason:
- DELETE: stale, superseded, or speculative notes
- MERGE: two files covering one topic
- ORPHANS: files reachable from no index or note
- QUALITY: notes failing the bar "an agent would get this wrong without it"
Return a markdown list of: action | file | reason. Propose only — do NOT
edit anything.
```

## 3. Early-exit gate

Fewer than 3 actionable findings → report "vault is healthy" and stop.
Don't churn a clean vault.

## 4. Reviewer (pattern pass)

Dispatch a second general-purpose agent:

```
Read the Sobaya brain vault at <absolute path>/brain and the skills in
.Codex/skills/.
1. Patterns: lessons appearing in 2+ notes that no principle captures →
   propose a principle (name, rule, why, evidence wikilinks). Candidates
   must be independent, evidenced by 2+ notes, and actionable.
2. Contradictions: skill instructions that conflict with brain principles
   or notes → cite both sides, propose the smaller fix.
3. Missing wikilinks between clearly related notes.
Propose only — do NOT edit anything.
```

## 5. Judge and apply

Review both reports against the actual files; reject weak proposals (false
positives are normal). Present the consolidated change list to the user,
then apply the approved ones: edit/delete/merge notes, add principles (and
update `brain/principles.md`), fix skills, add wikilinks.

## 6. Housekeep

- Move completed plan dirs to `brain/archive/plans/`; tick their entries in
  `brain/plans/index.md`.
- Move done todos to `brain/archive/completed_todos.md`.
- The index rebuilds itself via hook as you edit.

## Report

Counts: notes deleted/merged, principles added, skills fixed, plans
archived — plus what was rejected and why.
