# Check current code

Provider-neutral task reference; APP means apps/<name>.

Run gate.sh APP and report actual full-suite, hygiene and quality-tool evidence.
Quality tools run only when the app's AGENTS.md has `- Quality: required`;
equivalent mutants are listed in the app's `.sobaya-equivalent-mutants`, one
outcome key per line with a `#` reason. This command can check uncommitted
GREEN tidying and has no approval baseline or mandatory review prerequisite.
Passing tests do not prove user value. Independent review is available when
useful or requested; do not weaken tests to obtain GREEN.
