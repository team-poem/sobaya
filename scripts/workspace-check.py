#!/usr/bin/env python3
"""Read-only workspace checks for doctor and ordinary Git pre-commit hooks."""
import argparse
from pathlib import Path, PurePosixPath
import re
import runpy
import subprocess

MARKERS = {'package.json', 'pyproject.toml', 'Cargo.toml', 'go.mod', 'deno.json', 'composer.json'}
BRAIN = runpy.run_path(str(Path(__file__).with_name('brain-index.py')))


def git(repo, *args, optional=False):
    result = subprocess.run(['git', '-C', str(repo), *args], capture_output=True)
    if result.returncode and not optional:
        raise ValueError(result.stderr.decode(errors='replace').strip() or 'git command failed')
    return result.stdout.decode(errors='replace') if result.returncode == 0 else None


def registered(root, name):
    path = root / 'brain/apps.md'
    return path.is_file() and any(re.match(r'^\|\s*' + re.escape(name) + r'\s*\|', line)
                                  for line in path.read_text().splitlines())


def introduced(repo, staged):
    if staged:
        return git(repo, 'diff', '--cached', '--no-renames', '--name-only', '--diff-filter=A', '-z').split('\0')
    names = git(repo, 'ls-files', '--cached', '--others', '--exclude-standard', '-z').split('\0')
    return [name for name in names if name and git(repo, 'cat-file', '-e', 'HEAD:' + name, optional=True) is None]


def app_problems(root, app, staged=False):
    issues = []
    top = git(app, 'rev-parse', '--show-toplevel', optional=True)
    own_repo = top is not None and Path(top.strip()).resolve() == app.resolve()
    grandfathered = registered(root, app.name)
    if not own_repo:
        return [] if grandfathered else [f'{app}: app needs its own git repository; run tdd-set/bin/install.sh']
    for name in introduced(app, staged):
        path = PurePosixPath(name)
        if len(path.parts) > 1 and path.parts[0] in {'app', 'apps'} and path.name in MARKERS:
            issues.append(f'{app / name}: nested project marker; app root must be flat')
    if not grandfathered:
        content = git(app, 'show', ':AGENTS.md', optional=True) if staged else (
            (app / 'AGENTS.md').read_text() if (app / 'AGENTS.md').is_file() else '')
        commands = re.findall(r'^- Test:\s*`?([^`\n]+)', content or '', re.M)
        if not commands or any('<' in command or command.strip() in {'', 'true', ':'} for command in commands):
            issues.append(f'{app}: declare an actual - Test: command in AGENTS.md')
    return issues


def check(root, staged=False, app=None, apps=False):
    if app is not None:
        return app_problems(root, app.resolve(), staged)
    issues = []
    for name in introduced(root, staged):
        path = PurePosixPath(name)
        if path.name in MARKERS and path.parts[0] not in {'apps', 'references'}:
            issues.append(f'{name}: new projects belong under apps/<name>')
        if len(path.parts) > 3 and path.parts[0] == 'apps' and path.parts[2] in {'app', 'apps'} and path.name in MARKERS:
            issues.append(f'{name}: nested project marker; app root must be flat')
    if staged:
        changed = git(root, 'diff', '--cached', '--name-only', '-z').split('\0')
        if any(name.startswith('brain/') and name.endswith('.md') for name in changed):
            names = git(root, 'ls-files', '-z', '--', 'brain').split('\0')
            paths = [name[len('brain/'):] for name in names if name.startswith('brain/')]
            if (root / 'brain/apps.md').is_file() and 'apps.md' not in paths:
                paths.append('apps.md')  # per-clone, deliberately ignored registry
            expected = BRAIN['render'](paths)
            actual = git(root, 'show', ':brain/index.md', optional=True)
            if actual != expected:
                issues.append('brain/index.md is not the generated index for staged notes; run scripts/brain-index.py and stage the index with the notes')
    elif (root / 'brain').is_dir():
        index = root / 'brain/index.md'
        if index.is_symlink() or not index.is_file() or index.read_text() != BRAIN['render'](BRAIN['disk_paths'](root)):
            issues.append('brain/index.md is stale; run python3 scripts/brain-index.py <root>')
    if apps and (root / 'apps').is_dir():
        for candidate in sorted((root / 'apps').iterdir()):
            if candidate.is_dir() and not candidate.name.startswith('.'):
                for problem in app_problems(root, candidate):
                    print('WARN (existing app): ' + problem)
    return issues


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path)
    parser.add_argument('--staged', action='store_true', help='validate the staged changes for a Git commit')
    parser.add_argument('--app', type=Path, help='validate one app, including a linked worktree')
    parser.add_argument('--apps', action='store_true', help='report existing app compliance as warnings')
    args = parser.parse_args()
    try:
        issues = check(args.root.resolve(), args.staged, args.app, args.apps)
    except (OSError, ValueError) as exc:
        issues = [str(exc)]
    for problem in issues:
        print('ERROR: ' + problem)
    if not issues:
        print('workspace checks passed')
    return 1 if issues else 0


if __name__ == '__main__':
    raise SystemExit(main())
