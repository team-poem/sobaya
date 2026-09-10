"""Neutral Git hooks, setup, indexing and probe regression tests (stdlib only)."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class ToolTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sobaya tools ' ")
        self.base = Path(self.tmp.name)
        self.env = dict(os.environ, GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM='1', PYTHONDONTWRITEBYTECODE='1')

    def tearDown(self):
        self.tmp.cleanup()

    def run_cmd(self, *args, cwd=None, env=None, stdin=None):
        return subprocess.run([str(arg) for arg in args], cwd=cwd, env=env or self.env,
                              input=stdin, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)

    def git(self, repo, *args):
        result = self.run_cmd('git', '-C', repo, *args)
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout.strip()

    def repo(self, name='repo'):
        path = self.base / name
        path.mkdir()
        self.git(path, 'init', '-q')
        self.git(path, 'config', 'user.name', 'Fixture')
        self.git(path, 'config', 'user.email', 'fixture@example.invalid')
        self.git(path, 'config', 'commit.gpgsign', 'false')
        return path

    def script(self, name, *args):
        return self.run_cmd(sys.executable, ROOT / 'scripts' / name, *args)

    def install(self, app):
        return self.run_cmd('bash', ROOT / 'tdd-set/bin/install.sh', app)

    def agents(self, app, more=''):
        (app / 'AGENTS.md').write_text('# app\n- Test: `python3 -m unittest`\n' + more)

    def test_brain_golden_and_idempotence(self):
        root = self.base
        notes = ['vision', 'principles', 'principles/prove-it-works', 'apps', 'codebase/note',
                 'todos', 'plans/index', 'archive/done', 'plans/01-work/detail',
                 'archive/plans/00-work/detail', 'scratchpad']
        for name in notes:
            path = root / 'brain' / (name + '.md')
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text('# note\n')
        result = self.script('brain-index.py', root)
        self.assertEqual(result.returncode, 0, result.stdout)
        index = root / 'brain/index.md'
        text = index.read_text()
        self.assertIn('## Other\n- [[scratchpad]]', text)
        self.assertIn('## Principles\n- [[principles]]\n- [[principles/prove-it-works]]', text)
        self.assertNotIn('detail', text)
        os.utime(index, (946684800, 946684800))
        before = index.stat().st_mtime_ns
        self.assertEqual(self.script('brain-index.py', root).returncode, 0)
        self.assertEqual(index.stat().st_mtime_ns, before)
        self.assertEqual(self.script('brain-index.py', root, '--check').returncode, 0)

    def test_brain_check_does_not_write_and_symlink_rejected(self):
        (self.base / 'brain').mkdir()
        self.assertEqual(self.script('brain-index.py', self.base, '--check').returncode, 1)
        self.assertFalse((self.base / 'brain/index.md').exists())
        target = self.base / 'external'; target.write_text('preserved')
        (self.base / 'brain/index.md').symlink_to(target)
        self.assertEqual(self.script('brain-index.py', self.base).returncode, 1)
        self.assertEqual(target.read_text(), 'preserved')

    def test_workspace_new_marker_and_existing_marker(self):
        root = self.repo()
        (root / 'package.json').write_text('{}')
        self.git(root, 'add', '.')
        self.assertEqual(self.script('workspace-check.py', root, '--staged').returncode, 1)
        self.git(root, 'commit', '-qm', 'pre-existing marker')
        (root / 'package.json').write_text('{"name":"old"}')
        self.git(root, 'add', '.')
        self.assertEqual(self.script('workspace-check.py', root, '--staged').returncode, 0)
        (root / 'references/demo').mkdir(parents=True)
        (root / 'references/demo/package.json').write_text('{}')
        self.git(root, 'add', '.')
        self.assertEqual(self.script('workspace-check.py', root, '--staged').returncode, 0)

    def test_renamed_marker_is_still_a_new_marker(self):
        root = self.repo()
        (root / 'example.txt').write_text('{}')
        self.git(root, 'add', '.')
        self.git(root, 'commit', '-qm', 'existing plain file')
        self.git(root, 'mv', 'example.txt', 'package.json')
        result = self.script('workspace-check.py', root, '--staged')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('new projects belong', result.stdout)

    def test_staged_index_uses_staged_notes(self):
        root = self.repo()
        (root / 'brain').mkdir()
        (root / 'brain/vision.md').write_text('# Vision')
        self.script('brain-index.py', root)
        self.git(root, 'add', 'brain')
        self.assertEqual(self.script('workspace-check.py', root, '--staged').returncode, 0)
        (root / 'brain/unstaged.md').write_text('not staged')
        self.assertEqual(self.script('workspace-check.py', root, '--staged').returncode, 0)
        (root / 'brain/index.md').write_text('# tampered\n')
        self.git(root, 'add', 'brain/index.md')
        result = self.script('workspace-check.py', root, '--staged')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('generated index', result.stdout)

    def test_root_real_hook_rejects_manual_index_and_accepts_generated_index(self):
        root = self.repo()
        shutil.copytree(ROOT / 'scripts', root / 'scripts')
        shutil.copytree(ROOT / '.githooks', root / '.githooks')
        self.git(root, 'config', 'core.hooksPath', '.githooks')
        (root / 'brain').mkdir()
        (root / 'brain/vision.md').write_text('# Vision')
        (root / 'brain/index.md').write_text('# handwritten')
        self.git(root, 'add', '.')
        result = self.run_cmd('git', '-C', root, 'commit', '-qm', 'bad index')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn('generated index', result.stdout)
        self.script('brain-index.py', root)
        self.git(root, 'add', 'brain/index.md')
        result = self.run_cmd('git', '-C', root, 'commit', '-qm', 'generated index')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_app_registration_and_nesting(self):
        root = self.repo('workspace')
        app = self.repo('demo')
        self.assertEqual(self.script('workspace-check.py', root, '--app', app).returncode, 1)
        self.agents(app)
        self.assertEqual(self.script('workspace-check.py', root, '--app', app).returncode, 0)
        (app / 'app').mkdir(); (app / 'app/package.json').write_text('{}')
        self.git(app, 'add', '.')
        self.assertEqual(self.script('workspace-check.py', root, '--app', app, '--staged').returncode, 1)
        (root / 'brain').mkdir()
        (root / 'brain/apps.md').write_text('| legacy | imported |\n')
        legacy = self.base / 'legacy'; legacy.mkdir()
        self.assertEqual(self.script('workspace-check.py', root, '--app', legacy).returncode, 0)

    def test_existing_apps_only_warn_on_opt_in(self):
        root = self.repo()
        (root / 'apps/legacy').mkdir(parents=True)
        self.assertEqual(self.script('workspace-check.py', root).returncode, 0)
        result = self.script('workspace-check.py', root, '--apps')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('WARN', result.stdout)

    def setup_root(self):
        root = self.repo('harness root')
        shutil.copytree(ROOT / 'scripts', root / 'scripts')
        shutil.copytree(ROOT / '.githooks', root / '.githooks')
        return root

    def test_setup_activation_and_read_only_idempotent_check(self):
        root = self.setup_root()
        config = root / '.git/config'
        before = config.read_bytes()
        result = self.script('setup.py', root, '--check')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertEqual(config.read_bytes(), before)
        result = self.script('setup.py', root)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.git(root, 'config', '--get', 'core.hooksPath'), '.githooks')
        before = config.stat().st_mtime_ns
        self.assertEqual(self.script('setup.py', root).returncode, 0)
        self.assertEqual(self.script('setup.py', root, '--check').returncode, 0)
        self.assertEqual(config.stat().st_mtime_ns, before)

    def test_setup_preserves_conflicting_custom_hooks_config(self):
        root = self.setup_root()
        self.git(root, 'config', 'core.hooksPath', 'user hooks')
        before = (root / '.git/config').read_bytes()
        result = self.script('setup.py', root)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('Conflicting core.hooksPath', result.stdout)
        self.assertEqual((root / '.git/config').read_bytes(), before)

    def test_setup_does_not_shadow_existing_default_git_hook(self):
        root = self.setup_root()
        hook = root / '.git/hooks/commit-msg'
        hook.write_text('#!/bin/sh\necho user hook\n')
        before = (root / '.git/config').read_bytes()
        result = self.script('setup.py', root)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('would be shadowed', result.stdout)
        self.assertEqual(hook.read_text(), '#!/bin/sh\necho user hook\n')
        self.assertEqual((root / '.git/config').read_bytes(), before)

    def test_setup_missing_or_disabled_root_hook_fails(self):
        root = self.setup_root()
        hook = root / '.githooks/pre-commit'
        hook.chmod(0o644)
        self.assertEqual(self.script('setup.py', root).returncode, 1)
        hook.chmod(0o755)
        self.assertEqual(self.script('setup.py', root).returncode, 0)
        hook.unlink()
        self.assertEqual(self.script('setup.py', root, '--check').returncode, 1)

    def test_setup_verifies_app_hook_and_detects_wrong_harness(self):
        root = self.setup_root()
        # Install via this temporary harness so its wrapper resolves to this root.
        shutil.copytree(ROOT / 'tdd-set', root / 'tdd-set')
        self.assertEqual(self.script('setup.py', root).returncode, 0)
        app = self.repo("app ' quoted")
        self.agents(app)
        result = self.run_cmd('bash', root / 'tdd-set/bin/install.sh', app)
        self.assertEqual(result.returncode, 0, result.stdout)
        result = self.script('setup.py', root, '--check', '--app', app)
        self.assertEqual(result.returncode, 0, result.stdout)
        hook = app / '.git/hooks/pre-commit'
        hook.chmod(0o644)
        self.assertEqual(self.script('setup.py', root, '--check', '--app', app).returncode, 1)
        hook.chmod(0o755)
        # A real hook pointing to a different harness must not count as current setup.
        self.assertEqual(self.install(app).returncode, 0)
        result = self.script('setup.py', root, '--check', '--app', app)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('not the managed hook for this harness', result.stdout)

    def test_setup_accepts_absolute_root_hooks_path_and_worktree(self):
        root = self.setup_root()
        self.git(root, 'config', 'core.hooksPath', str(root / '.githooks'))
        config = (root / '.git/config').read_bytes()
        self.assertEqual(self.script('setup.py', root, '--check').returncode, 0)
        self.assertEqual(self.script('setup.py', root).returncode, 0)
        self.assertEqual((root / '.git/config').read_bytes(), config)
        # Relative configuration resolves to each linked worktree's checked-out hooks.
        self.git(root, 'config', 'core.hooksPath', '.githooks')
        self.git(root, 'add', '.')
        self.git(root, 'commit', '-qm', 'harness')
        worktree = self.base / 'linked harness'
        self.git(root, 'worktree', 'add', '-qb', 'isolated', str(worktree))
        self.assertTrue((worktree / '.git').is_file())
        result = self.script('setup.py', worktree, '--check')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_install_idempotent_and_no_invented_stack(self):
        app = self.repo()
        result = self.install(app)
        self.assertEqual(result.returncode, 0, result.stdout)
        agents = (app / 'AGENTS.md').read_text()
        self.assertIn('<declare the actual test command>', agents)
        self.assertNotIn('go test', agents)
        self.assertNotIn('Lint:', agents)
        self.assertFalse((app / 'CLAUDE.md').exists())
        (app / 'spec.md').write_text('human goal')
        (app / 'failed-test.md').write_text('human tests')
        hook = app / '.git/hooks/pre-commit'
        previous = hook.read_bytes()
        self.assertEqual(self.install(app).returncode, 0)
        self.assertEqual(hook.read_bytes(), previous)
        self.assertEqual((app / 'spec.md').read_text(), 'human goal')
        self.assertEqual((app / 'failed-test.md').read_text(), 'human tests')

    def test_install_only_declares_present_node_scripts(self):
        app = self.repo()
        (app / 'package.json').write_text(json.dumps({'scripts': {'test': 'node --test'}, 'devDependencies': {'prettier': '1'}}))
        self.assertEqual(self.install(app).returncode, 0)
        agents = (app / 'AGENTS.md').read_text()
        self.assertIn('npm test', agents)
        self.assertNotIn('Lint:', agents)
        self.assertNotIn('Format:', agents)

    def test_existing_custom_hook_preserved_before_docs(self):
        app = self.repo()
        self.git(app, 'config', 'core.hooksPath', 'custom hooks')
        hook = app / 'custom hooks/pre-commit'; hook.parent.mkdir()
        hook.write_text('#!/bin/sh\necho user hook\n')
        result = self.install(app)
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('existing pre-commit hook preserved', result.stdout)
        self.assertEqual(hook.read_text(), '#!/bin/sh\necho user hook\n')
        self.assertFalse((app / 'AGENTS.md').exists())
        self.assertFalse((app / 'spec.md').exists())

    def test_custom_hook_directory_without_conflict(self):
        app = self.repo()
        self.git(app, 'config', 'core.hooksPath', 'custom hooks')
        result = self.install(app)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertTrue((app / 'custom hooks/pre-commit').is_file())

    def test_install_linked_worktree_preserves_git_metadata(self):
        app = self.repo()
        self.agents(app); self.git(app, 'add', '.'); self.git(app, 'commit', '-qm', 'base')
        worktree = self.base / 'linked worktree'
        self.git(app, 'worktree', 'add', '-qb', 'isolated', str(worktree))
        before = (worktree / '.git').read_bytes()
        result = self.install(worktree)
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual((worktree / '.git').read_bytes(), before)
        self.assertEqual(self.script('workspace-check.py', self.base, '--app', worktree).returncode, 0)

    def test_real_commit_allows_formatter_success_output(self):
        app = self.repo("quoted ' app")
        self.agents(app, '- Format: `printf "All matched files use the style!\\n"`\n- Lint: `printf "lint passed\\n"`\n')
        self.assertEqual(self.install(app).returncode, 0)
        self.git(app, 'add', '.')
        result = self.run_cmd('git', '-C', app, 'commit', '-qm', 'valid')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('All matched files', result.stdout)

    def test_real_commit_rejects_lint_exit(self):
        app = self.repo()
        self.agents(app, '- Lint: `exit 7`\n')
        self.assertEqual(self.install(app).returncode, 0)
        self.git(app, 'add', '.')
        result = self.run_cmd('git', '-C', app, 'commit', '-qm', 'invalid')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Lint check failed', result.stdout)

    @unittest.skipUnless(shutil.which('gofmt'), 'gofmt unavailable')
    def test_gofmt_listing_adapter_with_quoted_path(self):
        app = self.repo()
        self.agents(app, '- Format: `gofmt -l "source dir"`\n')
        (app / 'source dir').mkdir(); (app / 'source dir/main.go').write_text('package demo\nfunc Add(a,b int)int{return a+b}\n')
        self.assertEqual(self.install(app).returncode, 0)
        self.git(app, 'add', '.')
        result = self.run_cmd('git', '-C', app, 'commit', '-qm', 'bad style')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('Format check failed', result.stdout)
        self.run_cmd('gofmt', '-w', app / 'source dir/main.go')
        self.git(app, 'add', '.')
        self.assertEqual(self.run_cmd('git', '-C', app, 'commit', '-qm', 'formatted').returncode, 0)

    def node(self):
        app = self.base / 'node app'; app.mkdir()
        (app / 'package.json').write_text('{"type":"commonjs"}')
        return app

    def probe(self, app, snippet, env=None):
        result = self.run_cmd(sys.executable, ROOT / 'scripts/probe.py', app, '-', env=env, stdin=snippet)
        self.assertEqual(list(app.glob('zz_sobaya_probe_*')), [])
        return result

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_node_green_assertion_and_syntax(self):
        app = self.node()
        prefix = 'const test=require("node:test"); const assert=require("node:assert/strict");\n'
        result = self.probe(app, prefix + 'test("green",()=>assert.equal(1,1));')
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn('GREEN', result.stdout)
        result = self.probe(app, prefix + 'test("red",()=>assert.equal(1,2));')
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('RED', result.stdout)
        result = self.probe(app, prefix + 'test("syntax",()=>{ broken syntax });')
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('ERROR', result.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_skip_is_error_and_explicit_thrown_failure_is_red(self):
        app = self.node()
        result = self.probe(app, 'const test=require("node:test"); test("skipped", {skip:true},()=>{});')
        self.assertEqual(result.returncode, 2, result.stdout)
        result = self.probe(app, 'const test=require("node:test"); test("custom",()=>{throw new Error("requirement not met")});')
        self.assertEqual(result.returncode, 0, result.stdout)

    @unittest.skipUnless(shutil.which('go'), 'go unavailable')
    def test_probe_go_syntax_skip_and_mixed_undefined_error(self):
        app = self.base / 'go app'; app.mkdir()
        (app / 'go.mod').write_text('module fixture\n\ngo 1.22\n')
        (app / 'app.go').write_text('package fixture\n')
        cases = ['func TestSyntax(t *testing.T) { broken syntax }',
                 'func TestSkip(t *testing.T) { t.Skip("not run") }',
                 'import ("testing"; "fmt")\nfunc TestMixed(t *testing.T) { MissingApi() }']
        for snippet in cases:
            result = self.probe(app, snippet, dict(self.env, SOBAYA_PROBE_ALLOW_UNDEFINED='1'))
            self.assertEqual(result.returncode, 2, result.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_undefined_requires_explicit_intent(self):
        app = self.node()
        snippet = 'const test=require("node:test"); test("newApi",()=>MissingApi());'
        self.assertEqual(self.probe(app, snippet).returncode, 2)
        result = self.probe(app, snippet, dict(self.env, SOBAYA_PROBE_ALLOW_UNDEFINED='1'))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn('explicitly allowed', result.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_missing_dependency_is_error_even_with_undefined_opt_in(self):
        app = self.node()
        snippet = 'const test=require("node:test"); require("missing-sobaya-dependency"); test("newApi",()=>MissingApi());'
        result = self.probe(app, snippet, dict(self.env, SOBAYA_PROBE_ALLOW_UNDEFINED='1'))
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('Cannot find module', result.stdout)

    def test_probe_missing_runtime_is_error(self):
        app = self.node()
        empty_path = self.base / 'empty-bin'; empty_path.mkdir()
        result = self.probe(app, 'test("candidate",()=>{});', dict(self.env, PATH=str(empty_path)))
        self.assertEqual(result.returncode, 2)
        self.assertIn('missing runtime: node', result.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_timeout_is_error_and_cleans_up(self):
        app = self.node()
        result = self.probe(app, 'const test=require("node:test"); test("stuck",()=>{while(true){}});', dict(self.env, SOBAYA_PROBE_TIMEOUT='0.5'))
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('timeout after', result.stdout)

    @unittest.skipUnless(shutil.which('node'), 'node unavailable')
    def test_probe_missing_vitest_does_not_download(self):
        app = self.node()
        (app / 'package.json').write_text('{"devDependencies":{"vitest":"1"}}')
        result = self.probe(app, 'test("candidate",()=>{});')
        self.assertEqual(result.returncode, 2, result.stdout)
        self.assertIn('vitest is not installed locally', result.stdout)
        self.assertFalse((app / 'node_modules').exists())


if __name__ == '__main__':
    unittest.main(verbosity=2)
