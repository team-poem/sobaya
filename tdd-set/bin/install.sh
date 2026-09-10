#!/usr/bin/env bash
# Register one app and install its ordinary Git pre-commit hook. Idempotent.
set -eu
here=$(cd "$(dirname "$0")/.." && pwd)
exec python3 - "$here" "${1:?usage: install.sh apps/<name>}" <<'PY'
from pathlib import Path
import json
import shlex
import subprocess
import sys

harness = Path(sys.argv[1]).resolve()
app = Path(sys.argv[2]).resolve()

def git(*args, optional=False):
    result = subprocess.run(['git', '-C', str(app), *args], text=True, capture_output=True)
    if result.returncode and not optional:
        raise ValueError(result.stderr.strip() or 'git failed')
    return result.stdout.strip() if result.returncode == 0 else None

try:
    app.mkdir(parents=True, exist_ok=True)
    if not (app / '.git').exists():
        git('init', '-q', '-b', 'main')
    if Path(git('rev-parse', '--show-toplevel')).resolve() != app:
        raise ValueError(f'{app} is not its own git repository')
    hookpath = git('rev-parse', '--git-path', 'hooks/pre-commit')
    hook = Path(hookpath)
    if not hook.is_absolute():
        hook = app / hook
    hook = hook.absolute()
    custom = git('config', '--get', 'core.hooksPath', optional=True)
    if custom and not hook.resolve().is_relative_to(app):
        raise ValueError(f'custom shared hooksPath is configured ({custom}); preserve it and chain {harness / "hooks/pre-commit.py"} manually')
    marker = '# Sobaya app pre-commit v1'
    content = '#!/bin/sh\n' + marker + '\nexec python3 ' + shlex.quote(str(harness / 'hooks/pre-commit.py')) + '\n'
    if hook.is_symlink() or (hook.exists() and (not hook.is_file() or marker not in hook.read_text().splitlines()[:2])):
        raise ValueError(f'existing pre-commit hook preserved: {hook}; chain {harness / "hooks/pre-commit.py"} manually and configure app documents without replacing the existing hook')
    # Check conflicts before creating or changing any app documents.
    if not (app / 'AGENTS.md').exists():
        lines = []
        if (app / 'package.json').is_file():
            package = json.loads((app / 'package.json').read_text())
            scripts = package.get('scripts', {})
            if scripts.get('test'):
                lines.append('- Test: `npm test`')
            if scripts.get('lint'):
                lines.append('- Lint: `npm run lint`')
            if scripts.get('format:check'):
                lines.append('- Format: `npm run format:check`')
            lines.append('- Skills: nodejs')
        elif (app / 'go.mod').is_file():
            lines = ['- Test: `go test ./...`', '- Format: `gofmt -l .`',
                     '- Lint: `go vet ./...`', '- Bench: `go test -bench=. -benchmem ./...`', '- Skills: go-mistakes']
        if not any(line.startswith('- Test:') for line in lines):
            lines.insert(0, '- Test: `<declare the actual test command>`')
        text = f'# {app.name}\n\n<One line: what this app is.>\n\n## App facts\n' + '\n'.join(lines)
        text += '\n\nFollow this file and the workspace AGENTS.md. The shared TDD rules are in tdd-set/AGENTS.md.\n'
        (app / 'AGENTS.md').write_text(text)
    for filename, template in [('spec.md', 'spec-template.md'), ('failed-test.md', 'failed-test-template.md')]:
        if not (app / filename).exists():
            (app / filename).write_bytes((harness / template).read_bytes())
    hook.parent.mkdir(parents=True, exist_ok=True)
    if not hook.exists() or hook.read_text() != content:
        hook.write_text(content)
    hook.chmod(0o755)
    print(f'{app} ready: AGENTS.md, spec.md, failed-test.md; Git pre-commit installed at {hook}')
    print('Fill spec.md and the actual Test/Format/Lint commands in AGENTS.md before planning.')
except (OSError, ValueError, TypeError) as exc:
    print(f'ERROR: {exc}', file=sys.stderr)
    raise SystemExit(1)
PY
