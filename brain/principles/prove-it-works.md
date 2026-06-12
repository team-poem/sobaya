# Prove It Works

**Rule:** Every output is verified by checking the real thing directly —
never by proxies, "it compiles", or a subagent's self-report.

**Why:** Unverified work has unknown correctness. A subagent saying "done"
is a claim, not evidence; acting on wrong claims costs more than checking.

**In practice:**
- After a subagent reports completion, read the artifact it produced (diff,
  file, test output) before advancing the pipeline.
- Hooks and scripts are verified by running them against synthetic inputs,
  not by reading them.
- "Tests pass" means you ran them and saw the output in this session.

See also: [[principles/fix-root-causes]]
