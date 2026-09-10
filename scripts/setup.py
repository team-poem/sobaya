#!/usr/bin/env python3
"""Activate neutral Git hooks, or verify setup without running a worker."""
import argparse
import os
from pathlib import Path
import shlex
import subprocess
import sys


def git(repo, *args, optional=False):
    result = subprocess.run(['git', '-C', str(repo), *args], text=True, capture_output=True)
    if result.returncode:
        if optional:
            return None
        raise ValueError(result.stderr.strip() or 'git command failed')
    return result.stdout.strip()


def repository(path):
    path = path.resolve()
    top = git(path, 'rev-parse', '--show-toplevel')
    if Path(top).resolve() != path:
        raise ValueError(f'{path} must be the repository root')
    return path


def effective_hook(repo):
    path = Path(git(repo, 'rev-parse', '--git-path', 'hooks/pre-commit'))
    return (path if path.is_absolute() else repo / path).resolve()


def require_executable(path, description):
    if not path.is_file() or not os.access(path, os.X_OK):
        raise ValueError(f'{description} is missing or not executable: {path}')


def root_check(root):
    expected = root / '.githooks/pre-commit'
    require_executable(expected, 'Root pre-commit')
    if not (root / 'scripts/workspace-check.py').is_file():
        raise ValueError(f'workspace checker is missing: {root / "scripts/workspace-check.py"}')
    if effective_hook(root) != expected.resolve():
        raise ValueError(f'Root hooks are not active; run python3 scripts/setup.py {shlex.quote(str(root))}')


def app_check(root, app):
    app = repository(app)
    hook = effective_hook(app)
    require_executable(hook, 'App pre-commit')
    helper = root / 'tdd-set/hooks/pre-commit.py'
    if not helper.is_file():
        raise ValueError(f'app hook helper is missing: {helper}')
    expected = '#!/bin/sh\n# Sobaya app pre-commit v1\nexec python3 ' + shlex.quote(str(helper)) + '\n'
    if hook.read_text() != expected:
        raise ValueError(f'App pre-commit is not the managed hook for this harness: {hook}; preserve custom hooks and inspect their integration, or rerun tdd-set/bin/install.sh for an outdated managed hook')
    print(f'App hook active: {hook}')


def activate(root):
    expected = root / '.githooks/pre-commit'
    require_executable(expected, 'Root pre-commit')
    if not (root / 'scripts/workspace-check.py').is_file():
        raise ValueError(f'workspace checker is missing: {root / "scripts/workspace-check.py"}')
    current = effective_hook(root)
    configured = git(root, 'config', '--get', 'core.hooksPath', optional=True)
    if current == expected.resolve():
        root_check(root)
        print('Root hooks already active; configuration unchanged')
        return
    if configured is not None:
        # Do not print configuration contents; only report the conflicting setting.
        raise ValueError('Conflicting core.hooksPath is configured; it was preserved. Integrate the existing hooks explicitly before activating Sobaya hooks.')
    if current.parent.is_dir():
        existing = [p.name for p in current.parent.iterdir()
                    if not p.name.endswith('.sample') and (p.is_file() or p.is_symlink())]
        if existing:
            raise ValueError('Existing Git hooks would be shadowed; preserved: ' + ', '.join(sorted(existing)) + '. Integrate them explicitly before activating Sobaya hooks.')
    git(root, 'config', '--local', 'core.hooksPath', '.githooks')
    root_check(root)
    print(f'Root hooks activated: {expected}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='Sobaya repository root')
    parser.add_argument('--check', action='store_true', help='read-only setup validation')
    parser.add_argument('--app', type=Path, help='also verify this app hook; requires --check')
    args = parser.parse_args()
    if args.app and not args.check:
        parser.error('--app is a validation option; use --check or install the app with tdd-set/bin/install.sh')
    try:
        root = repository(args.root)
        if args.check:
            root_check(root)
            print(f'Root hook active: {root / ".githooks/pre-commit"}')
            if args.app:
                app_check(root, args.app)
            print('Setup checks passed; no worker was invoked')
        else:
            activate(root)
        return 0
    except (OSError, ValueError) as exc:
        print(f'ERROR: {exc}', file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
