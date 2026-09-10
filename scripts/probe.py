#!/usr/bin/env python3
"""Probe a candidate test, separating failing behavior from infrastructure errors."""
import argparse
import json
import math
import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import sys
import tempfile


class ProbeError(Exception):
    pass


def run(command, cwd, timeout):
    try:
        child = subprocess.Popen(command, cwd=cwd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                 text=True, start_new_session=True)
    except OSError as exc:
        raise ProbeError(f'cannot run {command[0]}: {exc}') from exc
    try:
        output, _ = child.communicate(timeout=timeout)
    except subprocess.TimeoutExpired:
        os.killpg(child.pid, signal.SIGKILL)
        output, _ = child.communicate()
        raise ProbeError(f'timeout after {timeout:g}s: {command[0]}\n{output}')
    except BaseException:
        if child.poll() is None:
            os.killpg(child.pid, signal.SIGKILL)
            child.communicate()
        raise
    if child.returncode < 0:
        raise ProbeError(f'{command[0]} terminated by signal {-child.returncode}\n{output}')
    return child.returncode, output


def runtime(name):
    if not shutil.which(name):
        raise ProbeError(f'missing runtime: {name}')


def probe(directory, snippet, header, timeout, allow_undefined):
    directory = directory.resolve()
    if not directory.is_dir():
        raise ProbeError(f'test directory not found: {directory}')
    root = directory
    while not any((root / marker).is_file() for marker in ('go.mod', 'package.json')):
        if root.parent == root:
            raise ProbeError(f'no go.mod or package.json above {directory}')
        root = root.parent
    is_go = (root / 'go.mod').is_file()
    if is_go:
        runtime('go')
        runtime('gofmt')
        names = re.findall(r'\bfunc\s+(Test[A-Za-z0-9_]+)\s*\(', snippet)
        if len(names) != 1:
            raise ProbeError('snippet must contain exactly one func TestX')
        packages = []
        for file in sorted(directory.glob('*.go'), key=lambda p: (p.name.endswith('_test.go'), p.name)):
            match = re.search(r'^package\s+(\w+)', file.read_text(), re.M)
            if match:
                packages.append(match.group(1))
        package = packages[0] if packages else 'main'
        imports = '' if re.search(r'^import\b', snippet, re.M) else 'import "testing"\n\n'
        content = f'package {package}\n\n{imports}{snippet}\n'
        suffix = '_test.go'
    else:
        runtime('node')
        names = re.findall(r'\b(?:test|it)\s*\(\s*[\'\"]([^\'\"]+)', snippet)
        if len(names) != 1:
            raise ProbeError('snippet must contain exactly one test(...) or it(...)')
        package = json.loads((root / 'package.json').read_text())
        dependencies = {**package.get('dependencies', {}), **package.get('devDependencies', {})}
        vitest = 'vitest' in dependencies
        if vitest:
            runtime('npx')
            if not (root / 'node_modules/.bin/vitest').is_file():
                raise ProbeError('vitest is not installed locally; install dependencies before probing')
        ext = 'ts' if (root / 'tsconfig.json').exists() or 'typescript' in dependencies else 'js'
        content = (header + '\n' if header else '') + snippet + '\n'
        suffix = '.test.' + ext
    name = names[0]
    fd, filename = tempfile.mkstemp(prefix='zz_sobaya_probe_', suffix=suffix, dir=directory)
    path = Path(filename)
    try:
        with os.fdopen(fd, 'w') as output:
            output.write(content)
        if is_go:
            syntax_rc, syntax_output = run(['gofmt', '-e', str(path)], directory, timeout)
            if syntax_rc:
                raise ProbeError('Go syntax error\n' + syntax_output)
            rel = directory.relative_to(root).as_posix()
            command = ['go', 'test', '-json', './' + rel, '-run', '^' + re.escape(name) + '$', '-count=1']
        elif vitest:
            command = ['npx', '--no-install', 'vitest', 'run', path.relative_to(root).as_posix(),
                       '-t', '^' + re.escape(name) + '$']
        else:
            syntax_rc, syntax_output = run(['node', '--check', str(path)], root, timeout)
            if syntax_rc:
                raise ProbeError('Node syntax/runtime error\n' + syntax_output)
            command = ['node', '--test', '--test-name-pattern=^' + re.escape(name) + '$',
                       path.relative_to(root).as_posix()]
        rc, output = run(command, root, timeout)
        candidate_actions = []
        if is_go:
            diagnostics = []
            for line in output.splitlines(keepends=True):
                try:
                    event = json.loads(line)
                except ValueError:
                    diagnostics.append(line)
                    continue
                if event.get('Test') == name:
                    candidate_actions.append(event.get('Action'))
                if event.get('Output'):
                    diagnostics.append(event['Output'])
            output = ''.join(diagnostics)
        if output:
            print(output, end='' if output.endswith('\n') else '\n')
        if rc == 0:
            if (is_go and ('pass' not in candidate_actions or 'skip' in candidate_actions)) or re.search(r'\[no tests to run\]|\[no test files\]|No test files found|\btests 0\b|\bpass 0\b|\bTests\s+\d+ skipped', output):
                raise ProbeError('candidate test did not run')
            print(f'GREEN  {name}  (already passes — do not add to failed-test.md)')
            return 1
        # Infrastructure/parser failures take precedence even with undefined opt-in.
        infrastructure = (r'SyntaxError|syntax error|Cannot find (?:module|package)|ERR_MODULE_NOT_FOUND|'
                          r'Failed to resolve import|no required module provides package|missing go.sum|'
                          r'cannot find package|no such file or directory|permission denied|'
                          r'No test files found|ENOTFOUND|ECONNREFUSED|go: (?:downloading|errors parsing)|'
                          r'error TS\d+|is not a function|ERR_UNKNOWN_FILE_EXTENSION|ERR_UNSUPPORTED')
        if re.search(infrastructure, output, re.I):
            raise ProbeError('candidate could not run; fix syntax/dependencies/environment before recording it')
        undefined = re.search(r'undefined:\s*\w+|ReferenceError:\s*\w+ is not defined', output)
        compiler_errors = re.findall(r'^.+\.go:\d+:\d+: (.+)$', output, re.M) if is_go else []
        only_undefined = all(message.startswith('undefined:') for message in compiler_errors)
        if undefined and allow_undefined and only_undefined:
            print(f'RED    {name}  (undefined new symbol explicitly allowed)')
            return 0
        if undefined or re.search(r'build failed|FAIL[^\n]*\[setup failed\]', output):
            raise ProbeError('build/reference error; allow a deliberately new undefined symbol with SOBAYA_PROBE_ALLOW_UNDEFINED=1')
        behavioral = (r'--- FAIL: ' + re.escape(name) + r'\b' if is_go else
                      r'ERR_ASSERTION|AssertionError|expected .+ to |(?:not ok \d+ - |[✖×] )' + re.escape(name) + r'\b')
        if not re.search(behavioral, output):
            raise ProbeError('runner failed without a verified candidate assertion failure')
        print(f'RED    {name}  (fails: assertion/test failure; diagnostics above)')
        return 0
    finally:
        path.unlink(missing_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('snippet', help='file or - for stdin')
    parser.add_argument('header', nargs='?', type=Path)
    args = parser.parse_args()
    try:
        timeout = float(os.environ.get('SOBAYA_PROBE_TIMEOUT', '30'))
        if not math.isfinite(timeout) or timeout <= 0:
            raise ProbeError('SOBAYA_PROBE_TIMEOUT must be a positive number of seconds')
        snippet = sys.stdin.read() if args.snippet == '-' else Path(args.snippet).read_text()
        header = args.header.read_text() if args.header else ''
        return probe(args.directory, snippet, header, timeout, os.environ.get('SOBAYA_PROBE_ALLOW_UNDEFINED') == '1')
    except (OSError, ValueError, TypeError, ProbeError) as exc:
        print(f'ERROR  {exc}')
        return 2


if __name__ == '__main__':
    raise SystemExit(main())
