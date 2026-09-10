#!/usr/bin/env python3
"""App Git hook: workspace prerequisites, then declared Format and Lint checks."""
from pathlib import Path
import re
import shlex
import subprocess
import sys


def main():
    result = subprocess.run(['git', 'rev-parse', '--show-toplevel'], text=True, capture_output=True)
    if result.returncode:
        print('ERROR: Git pre-commit must run in an app repository', file=sys.stderr)
        return 1
    app = Path(result.stdout.strip())
    root = Path(__file__).resolve().parents[2]
    result = subprocess.run([sys.executable, str(root / 'scripts/workspace-check.py'), str(root), '--app', str(app), '--staged'])
    if result.returncode:
        return result.returncode
    try:
        agents = (app / 'AGENTS.md').read_text()
        for label in ('Format', 'Lint'):
            lines = re.findall(r'^- ' + label + r':\s*(.+)$', agents, re.M)
            if len(lines) > 1:
                raise ValueError(f'duplicate {label}: command in AGENTS.md')
            if not lines:
                continue
            command = lines[0].strip()
            if command.startswith('`') and command.endswith('`'):
                command = command[1:-1]
            if not command or '<' in command:
                raise ValueError(f'declare the actual {label}: command in AGENTS.md')
            # Generic commands use exit status. gofmt -l is the legacy listing exception.
            words = shlex.split(command)
            listing = label == 'Format' and len(words) > 1 and words[0] == 'gofmt' and words[1] == '-l'
            checked = subprocess.run(command, shell=True, cwd=app, text=True, capture_output=True)
            if checked.stdout:
                print(checked.stdout, end='')
            if checked.stderr:
                print(checked.stderr, end='', file=sys.stderr)
            if checked.returncode or (listing and checked.stdout.strip()):
                print(f'ERROR: {label} check failed: {command}', file=sys.stderr)
                return 1
        return 0
    except (OSError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
