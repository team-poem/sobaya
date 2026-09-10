#!/usr/bin/env python3
"""Shared, fail-closed acceptance checks. Python standard library only.

The approved Git commit is the authority. Runner results establish execution;
source comparisons independently establish that the approved tests were kept.
"""
from __future__ import annotations

import argparse
from dataclasses import dataclass, field
import difflib
import fnmatch
import json
import os
from pathlib import Path, PurePosixPath
import re
import shlex
import signal
import subprocess
import sys
import tempfile
from typing import Optional


class ContractError(RuntimeError):
    """The contract cannot be established; never a successful test result."""


@dataclass
class Entry:
    name: str
    checked: bool
    code: str
    header: str = ''
    heading: str = ''
    language: str = ''
    target: Optional[str] = None


@dataclass
class SuiteResults:
    runner: str
    passed: set[str] = field(default_factory=set)
    failed: set[str] = field(default_factory=set)
    skipped: set[str] = field(default_factory=set)
    output: str = ''


class TestFailure(ContractError):
    """A real named test executed and failed; .result contains its evidence."""
    def __init__(self, result: SuiteResults):
        self.result = result
        super().__init__('tests failed: ' + ', '.join(sorted(result.failed)) + '\n' + result.output[-12000:])


class BuildFailure(ContractError):
    """Runner/build failed without a verifiable named failing test."""
    def __init__(self, result: SuiteResults):
        self.result = result
        super().__init__('test runner failed without an executed failing test (build/infrastructure error)\n' + result.output[-12000:])


def _git_bytes(app, *args):
    try:
        process = subprocess.run(['git', '-C', str(app), *map(str, args)], capture_output=True)
    except OSError as error:
        raise ContractError('git unavailable: ' + str(error)) from error
    if process.returncode:
        raise ContractError('git ' + ' '.join(map(str, args)) + ': ' + process.stderr.decode(errors='replace').strip())
    return process.stdout


def git(app, *args) -> str:
    return _git_bytes(app, *args).decode('utf-8', errors='surrogateescape').strip()


def git_dir(app) -> Path:
    return Path(git(app, 'rev-parse', '--absolute-git-dir'))


def ensure_clean(app):
    app = Path(app).resolve()
    if Path(git(app, 'rev-parse', '--show-toplevel')).resolve() != app:
        raise ContractError('app must be the Git repository root')
    status = git(app, 'status', '--porcelain=v1', '--untracked-files=all')
    if status:
        raise ContractError('a clean working tree and index are required (including untracked files):\n' + status)


def _text(app, name, rev=None):
    try:
        if rev is not None:
            return _git_bytes(app, 'show', str(rev)+':'+name).decode('utf-8')
        path = Path(app)/name
        if path.is_symlink():
            raise ContractError(name + ' must be a regular file')
        return path.read_text(encoding='utf-8')
    except (OSError, UnicodeError) as error:
        raise ContractError('cannot read ' + name + ': ' + str(error)) from error


_ENTRY = re.compile(r'^- \[([ x])\] ([A-Za-z_][A-Za-z0-9_]*)(?:\s.*)?$')
_CHECKBOX = re.compile(r'^\s*[-*+]\s+\[[^\]]*\]')
_FENCE = re.compile(r'^```([A-Za-z0-9_-]*)\s*$')
_LANGUAGES = {'go', 'js', 'javascript', 'ts', 'typescript', 'jsx', 'tsx'}


def read_plan(text) -> list[Entry]:
    entries = []
    names = set()
    heading = header = ''
    section_has_entry = False
    pending = None
    lines = text.splitlines(keepends=True)
    i = 0
    while i < len(lines):
        line = lines[i].rstrip('\r\n')
        if line.startswith('## '):
            if pending:
                raise ContractError('missing code block for ' + pending[0])
            heading, header, section_has_entry = line, '', False
        match = _ENTRY.fullmatch(line)
        if match:
            if pending:
                raise ContractError('missing code block for ' + pending[0])
            name = match[2]
            if name in names:
                raise ContractError('duplicate plan entry: ' + name)
            names.add(name)
            pending = (name, match[1] == 'x')
            section_has_entry = True
        elif _CHECKBOX.match(line):
            raise ContractError('malformed plan entry: ' + line)
        fence = _FENCE.fullmatch(line)
        if fence:
            language = fence[1]
            i += 1
            block = []
            while i < len(lines) and lines[i].rstrip('\r\n') != '```':
                block.append(lines[i])
                i += 1
            if i == len(lines):
                raise ContractError('unclosed code block in plan')
            code = ''.join(block)
            if pending:
                name, checked = pending
                if language not in _LANGUAGES or not code.strip() or re.search(r'^\s*\.\.\.\s*$', code, re.M):
                    raise ContractError('missing, unsupported, or placeholder test code: ' + name)
                target_match = re.search(r'^// file:\s*(\S+)\s*$', header, re.M)
                target = target_match[1] if target_match else None
                if target and (PurePosixPath(target).is_absolute() or '..' in PurePosixPath(target).parts or '\\' in target):
                    raise ContractError('test target must stay inside the app: ' + target)
                if language != 'go' and not target:
                    raise ContractError('Node plan section needs a // file: header: ' + name)
                entries.append(Entry(name, checked, code, header, heading, language, target))
                pending = None
            elif not section_has_entry:
                if header:
                    raise ContractError('multiple section header blocks: ' + heading)
                header = code
        elif line.startswith('```'):
            raise ContractError('malformed code fence: ' + line)
        i += 1
    if pending:
        raise ContractError('missing code block for ' + pending[0])
    if not entries:
        raise ContractError('plan must contain at least one test entry')
    return entries


def load_plan(app, rev=None) -> list[Entry]:
    return read_plan(_text(app, 'failed-test.md', rev))


def _baseline(app, baseline):
    if not baseline or str(baseline).startswith('-'):
        raise ContractError('an approved baseline commit is required')
    commit = git(app, 'rev-parse', '--verify', str(baseline)+'^{commit}')
    git(app, 'merge-base', '--is-ancestor', commit, 'HEAD')
    return commit


def _normalized_plan(text):
    lines = []
    fenced = False
    for line in text.splitlines(keepends=True):
        if line.startswith('```'):
            fenced = not fenced
        if not fenced:
            line = re.sub(r'^- \[x\]', '- [ ]', line)
        lines.append(line)
    return ''.join(lines).rstrip('\n')


def _commands(text):
    return tuple(line for line in text.splitlines() if re.match(r'^- (?:Test|Test-File|Format|Lint|Bench):', line))


def validate_plan(app, baseline, allow_pending=True) -> list[Entry]:
    baseline = _baseline(app, baseline)
    approved_text = _text(app, 'failed-test.md', baseline)
    current_text = _text(app, 'failed-test.md', 'HEAD')
    approved = read_plan(approved_text)
    current = read_plan(current_text)
    old, new = _normalized_plan(approved_text), _normalized_plan(current_text)
    if not (new == old or new.startswith(old+'\n')):
        raise ContractError('approved plan text, code, and headers must not change or disappear')
    if len(current) < len(approved):
        raise ContractError('approved plan entries disappeared')
    for before, after in zip(approved, current):
        if before.name != after.name or (before.checked and not after.checked):
            raise ContractError('approved plan order and completed entries must not change')
    appended = current[len(approved):]
    if any(entry.checked for entry in appended):
        raise ContractError('unapproved appended entries cannot be checked')
    if not allow_pending and any(not entry.checked for entry in current):
        raise ContractError('unchecked plan entries remain: ' + ', '.join(entry.name for entry in current if not entry.checked))
    if _text(app, 'spec.md', baseline) != _text(app, 'spec.md', 'HEAD'):
        raise ContractError('approved spec.md must not change')
    old_commands = _commands(_text(app, 'AGENTS.md', baseline))
    new_commands = _commands(_text(app, 'AGENTS.md', 'HEAD'))
    if old_commands != new_commands:
        raise ContractError('approved AGENTS.md commands must not change')
    # npm indirection is part of the approved command, not an editable loophole.
    if any(re.search(r'\b(?:npm|npx|vitest)\b', command) for command in old_commands):
        old_package = _package(app, baseline)
        new_package = _package(app, 'HEAD')
        if old_package.get('scripts', {}) != new_package.get('scripts', {}):
            raise ContractError('approved package.json scripts must not change')
    return current


def _tree(app, rev):
    result = {}
    for record in _git_bytes(app, 'ls-tree', '-r', '-z', rev).split(b'\0'):
        if record:
            meta, name = record.split(b'\t', 1)
            mode, kind, oid = meta.decode().split()
            result[name.decode('utf-8', errors='surrogateescape')] = (mode, kind, oid)
    return result


def _protected(name):
    path = PurePosixPath(name)
    return any(part in {'test', 'tests', '__tests__'} for part in path.parts[:-1]) or any(fnmatch.fnmatch(path.name, pattern) for pattern in ('*_test.go', '*_test.py', 'test_*.py', '*.test.*', '*.spec.*', 'conftest.py'))


def _test_source(name):
    return any(fnmatch.fnmatch(PurePosixPath(name).name, pattern) for pattern in ('*_test.go', '*_test.py', 'test_*.py', '*.test.*', '*.spec.*'))


def _additions_only(name, before, after, explicit_test=False):
    if before == after:
        return True
    if b'\0' in before or b'\0' in after or not (_test_source(name) or explicit_test):
        return False
    # Tests are appended; fixtures/helpers cannot be edited. Go may add imports
    # in the import preamble without rewriting an existing line.
    if after.startswith(before) and (not before or before.endswith(b'\n')):
        return True
    if not name.endswith('_test.go'):
        return False
    old, new = before.splitlines(keepends=True), after.splitlines(keepends=True)
    first_func = next((i for i, line in enumerate(old) if re.match(rb'^func\s', line)), len(old))
    for tag, a, b, c, d in difflib.SequenceMatcher(None, old, new, autojunk=False).get_opcodes():
        if tag == 'equal':
            continue
        if tag != 'insert':
            return False
        if a == len(old):
            continue
        if a > first_func:
            return False
        for line in new[c:d]:
            if not re.fullmatch(rb'\s*(?:import\s+(?:\(|(?:[A-Za-z_]\w*\s+)?"[^"\n]+")|(?:[A-Za-z_]\w*\s+)?"[^"\n]+"|\))?\s*', line):
                return False
    return True


def _verify_sources(app, baseline, entries):
    before, after = _tree(app, baseline), _tree(app, 'HEAD')
    targets = {entry.target for entry in entries if entry.target}
    for name, info in before.items():
        if not (_protected(name) or name in targets):
            continue
        if name not in after or info[:2] != after[name][:2]:
            raise ContractError('protected test/fixture removed, renamed, or changed type: '+name)
        if info[2] != after[name][2] and not _additions_only(name, _git_bytes(app, 'cat-file', 'blob', info[2]), _git_bytes(app, 'cat-file', 'blob', after[name][2]), explicit_test=name in targets):
            raise ContractError('protected test/fixture modified: '+name)
    sources = {name: _git_bytes(app, 'cat-file', 'blob', info[2]) for name, info in after.items() if (_protected(name) or name in targets) and info[0] in {'100644', '100755'} and info[1] == 'blob'}
    for entry in entries:
        if not entry.checked:
            continue
        candidates = [entry.target] if entry.target else [name for name in sources if name.endswith('_test.go')]
        matches = [name for name in candidates if name in sources and entry.code.encode() in sources[name]]
        if not matches:
            raise ContractError('approved test is not verbatim in its committed test file: '+entry.name)
        if entry.header and entry.target and not sources[entry.target].startswith(entry.header.encode()):
            raise ContractError('approved test header is not verbatim: '+entry.name)


def _package(app, rev=None):
    try:
        value = json.loads(_text(app, 'package.json', rev))
    except ValueError as error:
        raise ContractError('invalid package.json: '+str(error)) from error
    if not isinstance(value, dict):
        raise ContractError('package.json must be an object')
    return value


def _test_command(app):
    matches = re.findall(r'^- Test:\s*`([^`]+)`\s*$', _text(app, 'AGENTS.md'), re.M)
    if len(matches) != 1:
        raise ContractError('AGENTS.md must declare exactly one - Test: `command` line')
    try:
        command = shlex.split(matches[0])
    except ValueError as error:
        raise ContractError('invalid Test command: '+str(error)) from error
    if not command or any(re.search(r'[;&|<>`\n]|\$\(', arg) for arg in command):
        raise ContractError('unsupported Test command: use a direct go test, node --test, or vitest run command')
    if command[:2] in (['npm', 'test'], ['npm', 'run']) or command[:2] == ['npm', 'run-script']:
        if command[1] == 'test':
            script, extra = 'test', command[2:]
        elif len(command) > 2:
            script, extra = command[2], command[3:]
        else:
            raise ContractError('unsupported npm Test command')
        scripts = _package(app).get('scripts', {})
        if not isinstance(scripts, dict) or not isinstance(scripts.get(script), str):
            raise ContractError('npm test script is missing')
        if scripts.get('pre'+script) or scripts.get('post'+script):
            raise ContractError('unsupported npm lifecycle hooks: declare the acceptance runner directly in Test')
        if extra[:1] == ['--']:
            extra = extra[1:]
        try:
            command = shlex.split(scripts[script])+extra
        except ValueError as error:
            raise ContractError('invalid npm test script') from error
        if any(re.search(r'[;&|<>`\n]|\$\(', arg) for arg in command):
            raise ContractError('unsupported npm test script: declare the acceptance runner directly in Test')
    if not command:
        raise ContractError('unsupported empty Test command')
    if command[:2] == ['npx', 'vitest']:
        command = command[1:]
    if command[:2] == ['go', 'test']:
        # Force actual execution instead of cached success.
        return 'go', command+['-json', '-count=1']
    if command[0] == 'node' and '--test' in command:
        if any(arg.startswith('--test-reporter') for arg in command):
            raise ContractError('unsupported Node reporter override; the gate selects TAP')
        position = command.index('--test')+1
        command[position:position] = ['--test-reporter=tap']
        return 'node', command
    if command[0] in {'vitest', './node_modules/.bin/vitest', 'node_modules/.bin/vitest'} and len(command) > 1 and command[1] == 'run':
        executable = Path(app)/'node_modules/.bin/vitest'
        if not executable.is_file():
            raise ContractError('Vitest is not installed locally; install the app dependencies first')
        if any(arg.startswith(('--reporter', '--outputFile', '--watch')) for arg in command[2:]):
            raise ContractError('unsupported Vitest reporter/watch override')
        return 'vitest', [str(executable), *command[1:]]
    raise ContractError('unsupported Test command: use go test, node --test, or locally installed vitest run (npm wrappers supported)')


def _stop_suite(process):
    try:
        os.killpg(process.pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return process.communicate()


def _run(command, app, timeout):
    try:
        process = subprocess.Popen(command, cwd=str(app), stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, errors='replace', start_new_session=True)
    except OSError as error:
        raise ContractError('test runner unavailable: '+str(error)) from error
    try:
        output, _ = process.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        output, _ = _stop_suite(process)
        raise ContractError('test runner timed out after '+str(timeout)+'s\n'+output[-12000:])
    except BaseException:
        _stop_suite(process)
        raise
    return process.returncode, output


def run_hygiene(app, timeout=300) -> dict[str, str]:
    """Run the app's declared checks; independent of installed Git hooks."""
    agents = _text(app, 'AGENTS.md')
    outputs = {}
    for kind in ('Format', 'Lint'):
        declarations = re.findall(r'^- '+kind+r':(.*)$', agents, re.M)
        if not declarations:
            continue
        if len(declarations) != 1:
            raise ContractError('AGENTS.md must declare at most one '+kind+' command')
        command = declarations[0].strip()
        if command.startswith('`'):
            if len(command) < 3 or not command.endswith('`'):
                raise ContractError('invalid '+kind+' command')
            command = command[1:-1]
        if not command.strip():
            raise ContractError('empty '+kind+' command')
        try:
            rc, output = _run(['sh', '-c', command], app, timeout)
        except ContractError as error:
            raise ContractError(kind+' check failed: '+str(error)) from error
        if rc:
            raise ContractError(kind+' check failed (exit '+str(rc)+'): '+command+'\n'+output[-12000:])
        # gofmt -l exits zero even when it lists unformatted files. Other
        # successful checkers (e.g. prettier --check) may print confirmations.
        try:
            tokens = shlex.split(command)
        except ValueError as error:
            raise ContractError('invalid '+kind+' command: '+str(error)) from error
        lists_gofmt = any(Path(token).name == 'gofmt' and any(re.fullmatch(r'-[A-Za-z]*l[A-Za-z]*', flag) for flag in tokens[i+1:]) for i, token in enumerate(tokens))
        if kind == 'Format' and lists_gofmt and output.strip():
            raise ContractError('Format needed ('+command+'):\n'+output[-12000:])
        outputs[kind] = output
    return outputs


def run_suite(app, timeout=300) -> SuiteResults:
    runner, command = _test_command(app)
    result = SuiteResults(runner)
    with tempfile.TemporaryDirectory(prefix='sobaya-results-') as directory:
        output_file = Path(directory)/'vitest.json'
        if runner == 'vitest':
            command += ['--reporter=json', '--outputFile='+str(output_file)]
        rc, output = _run(command, app, timeout)
        result.output = output
        if runner == 'go':
            saw_event = False
            for line in output.splitlines():
                try:
                    event = json.loads(line)
                except ValueError:
                    continue
                if not isinstance(event, dict):
                    continue
                saw_event = saw_event or 'Action' in event
                name, action = event.get('Test'), event.get('Action')
                if name and action in {'pass', 'fail', 'skip'}:
                    getattr(result, {'pass':'passed', 'fail':'failed', 'skip':'skipped'}[action]).add(name)
            valid = saw_event
        elif runner == 'node':
            valid = bool(re.search(r'^TAP version \d+$', output, re.M)) and bool(re.search(r'^1\.\.\d+\s*$', output, re.M))
            for line in output.splitlines():
                match = re.match(r'^\s*(not ok|ok) \d+ - (.*?)(?:\s+#\s*(SKIP|TODO)\b.*)?$', line, re.I)
                if not match:
                    continue
                name = match[2]
                # Node emits a file-level failure when a module cannot load. That
                # is infrastructure/build failure, not a behavioral RED.
                if (Path(app)/name).is_file() or Path(name).is_absolute():
                    continue
                collection = 'skipped' if match[3] else ('failed' if match[1] == 'not ok' else 'passed')
                getattr(result, collection).add(name)
        else:
            try:
                evidence = json.loads(output_file.read_text())
                valid = isinstance(evidence.get('testResults'), list)
                for suite in evidence.get('testResults', []):
                    for assertion in suite.get('assertionResults', []):
                        name = assertion.get('title')
                        status = assertion.get('status')
                        if name and status in {'passed', 'failed', 'pending', 'skipped', 'todo', 'disabled'}:
                            getattr(result, status if status in {'passed', 'failed'} else 'skipped').add(name)
            except (OSError, ValueError, AttributeError, TypeError):
                valid = False
    if not valid:
        if rc:
            raise BuildFailure(result)
        raise ContractError('test runner did not produce verifiable '+runner+' results\n'+output[-12000:])
    if result.failed:
        raise TestFailure(result)
    if rc:
        raise BuildFailure(result)
    return result


def _matches_name(title, name):
    return bool(re.match(re.escape(name)+r'(?:\b|$)', title))


def gate(app, baseline, complete=True, run_tests=True):
    ensure_clean(app)
    head = git(app, 'rev-parse', 'HEAD')
    baseline = _baseline(app, baseline)
    entries = validate_plan(app, baseline, allow_pending=not complete)
    _verify_sources(app, baseline, entries)
    if run_tests:
        run_hygiene(app)
        ensure_clean(app)
    result = run_suite(app) if run_tests else None
    if result is not None:
        for entry in entries:
            if not entry.checked:
                continue
            passed = [title for title in result.passed if _matches_name(title, entry.name)]
            skipped = [title for title in result.skipped if _matches_name(title, entry.name)]
            if not passed or skipped:
                raise ContractError('approved test was not executed successfully (missing or skipped): '+entry.name)
    if head != git(app, 'rev-parse', 'HEAD'):
        raise ContractError('HEAD changed during verification')
    ensure_clean(app)
    return result


def saved_baseline(app):
    metadata = git_dir(app)
    state = metadata/'sobaya/state.json'
    if state.exists():
        try:
            baseline = json.loads(state.read_text())['baseline']
        except (OSError, ValueError, KeyError, TypeError) as error:
            raise ContractError('invalid approval state: '+str(error)) from error
        if not isinstance(baseline, str) or not baseline:
            raise ContractError('approval state has no baseline')
        return _baseline(app, baseline)
    raise ContractError('no approved baseline; approve the plan before running the gate')


def main(argv=None):
    parser = argparse.ArgumentParser(description='Verify the approved plan against a clean committed app and real test results.')
    parser.add_argument('app')
    parser.add_argument('baseline', nargs='?')
    args = parser.parse_args(argv)
    try:
        baseline = args.baseline or saved_baseline(args.app)
        result = gate(args.app, baseline)
        print(result.output.rstrip())
        print('PASS')
    except ContractError as error:
        print('GATE FAILED: '+str(error), file=sys.stderr)
        return 1
    return 0


if __name__ == '__main__':
    sys.exit(main())
