#!/usr/bin/env python3
"""Generate the vault index explicitly; no editor or provider callbacks required."""
import argparse
import os
from pathlib import Path
import re
import tempfile


def render(paths):
    names = sorted({str(p)[:-3] for p in paths if str(p).endswith('.md')
                    and str(p) != 'index.md'
                    and not re.match(r'^(?:archive/)?plans/[^/]+/', str(p))})
    groups = [
        ('Vision', r'^vision$'), ('Principles', r'^principles(?:/|$)'),
        ('Apps', r'^apps$'), ('Codebase', r'^codebase/'), ('Backlog', r'^todos$'),
        ('Plans', r'^plans/index$'), ('Archive', r'^archive/'),
    ]
    result = '# Brain\n'
    remaining = set(names)
    for title, pattern in groups:
        matches = [name for name in names if re.search(pattern, name)]
        if matches:
            result += '\n## ' + title + '\n' + ''.join('- [[' + name + ']]\n' for name in matches)
            remaining.difference_update(matches)
    if remaining:
        result += '\n## Other\n' + ''.join('- [[' + name + ']]\n' for name in sorted(remaining))
    return result


def disk_paths(root):
    brain = Path(root) / 'brain'
    if not brain.is_dir():
        raise ValueError(f'brain directory not found: {brain}')
    # Do not follow symlinks outside the vault.
    return [p.relative_to(brain).as_posix() for p in brain.rglob('*.md')
            if p.is_file() and not p.is_symlink()]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root', type=Path, help='workspace root')
    parser.add_argument('--check', action='store_true', help='check without writing')
    args = parser.parse_args()
    root = args.root.resolve()
    target = root / 'brain/index.md'
    try:
        if target.is_symlink() or (target.exists() and not target.is_file()):
            raise ValueError(f'index must be a regular file: {target}')
        content = render(disk_paths(root))
        if target.exists() and target.read_text() == content:
            print('brain index current')
            return 0
        if args.check:
            print(f'ERROR: brain index is stale; run python3 scripts/brain-index.py {root}')
            return 1
        fd, tmp = tempfile.mkstemp(prefix='.index-', suffix='.tmp', dir=target.parent)
        try:
            with os.fdopen(fd, 'w') as output:
                output.write(content)
                output.flush()
                os.fsync(output.fileno())
            os.chmod(tmp, 0o644)
            os.replace(tmp, target)
        finally:
            if os.path.exists(tmp):
                os.unlink(tmp)
        print(f'updated {target}')
        return 0
    except (OSError, ValueError) as exc:
        print(f'ERROR: {exc}')
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
