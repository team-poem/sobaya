"""Acceptance contract regressions; fixtures are isolated Git repositories."""
import importlib.util
import json
import os
from pathlib import Path
import shutil
import signal
import time
import subprocess
import sys
import tempfile
import unittest

MODULE = Path(__file__).resolve().parents[1] / 'tdd-set/lib/contract.py'
spec = importlib.util.spec_from_file_location('contract', MODULE)
contract = importlib.util.module_from_spec(spec)
sys.modules['contract'] = contract
spec.loader.exec_module(contract)


@unittest.skipUnless(shutil.which('node'), 'Node is needed for real runner evidence')
class ContractTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix='sobaya-contract-')
        self.app = Path(self.tmp.name)
        self.git('init', '-q')
        self.git('config', 'user.email', 'test@example.invalid')
        self.git('config', 'user.name', 'Contract Test')
        self.git('config', 'commit.gpgsign', 'false')
        self.write('AGENTS.md', '- Test: `node --test calc.test.js`\n')
        self.write('spec.md', '# Addition\nReturn the sum of two numbers.\n')
        self.write('package.json', '{"type":"module"}\n')
        self.header = "// file: calc.test.js\nimport {test} from 'node:test';\nimport assert from 'node:assert/strict';\nimport {add} from './calc.js';\n"
        self.code = "test('addAdds: positive sum', () => assert.equal(add(1,2),3));\n"
        self.write('calc.test.js', self.header)
        self.write('calc.js', 'export const add = (a,b) => 0;\n')
        self.write('failed-test.md', '# Addition\n\n## Positive\n```js\n'+self.header+'```\n\n- [ ] addAdds — positive sum\n```js\n'+self.code+'```\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')

    def tearDown(self):
        self.tmp.cleanup()

    def git(self, *args):
        return subprocess.check_output(['git', '-C', str(self.app), *args], text=True, stderr=subprocess.STDOUT).strip()

    def write(self, name, text):
        path = self.app/name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)

    def commit(self):
        self.git('add', '-A')
        self.git('commit', '-qm', 'fixture')

    def green(self):
        self.write('calc.js', 'export const add = (a,b) => a+b;\n')
        self.write('calc.test.js', self.header+self.code)
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace('- [ ]', '- [x]'))
        self.commit()

    def assertRejected(self, message=None):
        with self.assertRaises(contract.ContractError) as error:
            contract.gate(self.app, self.baseline)
        if message:
            self.assertIn(message, str(error.exception))

    def test_valid_committed_test_passes(self):
        self.green()
        result = contract.gate(self.app, self.baseline)
        self.assertIn('addAdds: positive sum', result.passed)

    def test_pending_entry_rejected_for_completion(self):
        self.assertRejected('unchecked')

    def test_current_plan_cannot_weaken_approved_body(self):
        self.green()
        for file in ['failed-test.md', 'calc.test.js']:
            self.write(file, (self.app/file).read_text().replace('add(1,2),3', 'add(1,2),0'))
        self.write('calc.js', 'export const add = () => 0;\n')
        self.commit()
        self.assertRejected('approved plan')

    def test_pending_entry_cannot_be_deleted(self):
        self.write('failed-test.md', '# Addition\n')
        self.commit()
        self.assertRejected()

    def test_declared_format_and_lint_fail_without_git_hooks(self):
        initial = self.baseline
        for kind in ('Format', 'Lint'):
            with self.subTest(kind=kind):
                self.git('reset', '--hard', '-q', initial)
                self.git('config', 'core.hooksPath', '/dev/null')
                self.write('AGENTS.md', '- Test: `node --test calc.test.js`\n- '+kind+': `false`\n')
                self.commit()
                self.baseline = self.git('rev-parse', 'HEAD')
                self.green()
                self.assertRejected(kind)

    def test_hygiene_success_output_is_allowed_and_both_checks_run(self):
        self.write('AGENTS.md', '- Test: `node --test calc.test.js`\n- Format: `printf format-checked`\n- Lint: `printf lint-checked`\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        checks = contract.run_hygiene(self.app)
        self.assertEqual(checks, {'Format':'format-checked', 'Lint':'lint-checked'})
        self.assertIn('addAdds: positive sum', contract.gate(self.app, self.baseline).passed)

    def test_hygiene_source_mutation_is_rejected(self):
        self.write('AGENTS.md', '- Test: `node --test calc.test.js`\n- Format: `printf changed > impl.tmp`\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.assertRejected('clean')

    @unittest.skipUnless(shutil.which('gofmt'), 'Go formatter is optional')
    def test_gofmt_listing_is_failure_even_with_zero_exit(self):
        self.write('AGENTS.md', '- Test: `node --test calc.test.js`\n- Format: `gofmt -l unformatted.go`\n')
        self.write('unformatted.go', 'package calc\nfunc f( ) {}\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.assertRejected('Format')

    def test_spec_and_runner_commands_are_frozen(self):
        self.green()
        for path, text in [('spec.md', 'Changed goal\n'), ('AGENTS.md', '- Test: `true`\n')]:
            with self.subTest(path=path):
                old = (self.app/path).read_text()
                self.write(path, text)
                self.commit()
                self.assertRejected('approved')
                self.write(path, old)
                self.commit()

    def test_checkbox_like_text_inside_code_is_frozen(self):
        plan = (self.app/'failed-test.md').read_text().replace("import {add}", "const markdown = `\n- [ ] literal\n`;\nimport {add}")
        self.write('failed-test.md', plan)
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.write('failed-test.md', plan.replace('- [ ] literal', '- [x] literal'))
        self.commit()
        with self.assertRaisesRegex(contract.ContractError, 'approved plan'):
            contract.validate_plan(self.app, self.baseline)

    def test_header_shared_constant_cannot_change(self):
        self.green()
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace("import {add}", "// altered\nimport {add}"))
        self.commit()
        self.assertRejected('approved plan')

    def test_missing_and_invalid_baseline_fail_closed(self):
        self.green()
        with self.assertRaises(contract.ContractError):
            contract.gate(self.app, 'not-a-commit')
        self.git('rm', 'failed-test.md')
        self.commit()
        self.assertRejected()

    def test_dirty_worktree_cannot_mask_broken_head(self):
        self.green()
        self.write('calc.js', 'export const add = () => 0;\n')
        self.commit()
        self.write('calc.js', 'export const add = (a,b) => a+b;\n')
        self.assertRejected('clean')

    def test_index_and_untracked_inputs_are_rejected(self):
        self.green()
        self.write('calc.js', 'export const add = (a,b) => a+b+0;\n')
        self.git('add', 'calc.js')
        self.assertRejected('clean')
        self.git('reset', '--hard', '-q', 'HEAD')
        self.write('unexpected.js', 'export default 1;\n')
        self.assertRejected('clean')

    def test_negative_and_binary_fixture_changes_rejected(self):
        self.write('tests/expected.txt', '-3\n')
        (self.app/'tests/bytes.bin').write_bytes(b'\x00old')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.write('tests/expected.txt', '-0\n')
        self.commit()
        self.assertRejected('protected')
        self.git('checkout', self.baseline, '--', 'tests/expected.txt')
        (self.app/'tests/bytes.bin').write_bytes(b'\x00new')
        self.commit()
        self.assertRejected('protected')

    def test_test_rename_is_rejected(self):
        self.green()
        self.git('mv', 'calc.test.js', 'renamed.test.js')
        self.commit()
        self.assertRejected('protected')

    def test_commented_test_is_not_execution_evidence(self):
        self.green()
        self.write('calc.test.js', self.header+'/*\n'+self.code+'*/\n')
        self.commit()
        self.assertRejected('executed')

    def test_skipped_approved_test_is_not_passing_evidence(self):
        # The approved code itself can contain a skip: completion must still refuse it.
        self.code = "test('addAdds: positive sum', {skip: true}, () => assert.equal(add(1,2),3));\n"
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace("test('addAdds: positive sum', ()", "test('addAdds: positive sum', {skip: true}, ()"))
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.assertRejected('executed')

    def test_unverifiable_success_command_rejected(self):
        self.write('AGENTS.md', '- Test: `true`\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.assertRejected('unsupported')

    def test_appended_defect_is_pending_and_never_implicitly_approved(self):
        self.green()
        extra = "\n- [ ] addZero — zero\n```js\ntest('addZero', () => assert.equal(add(0,0),0));\n```\n"
        self.write('failed-test.md', (self.app/'failed-test.md').read_text()+extra)
        self.commit()
        entries = contract.validate_plan(self.app, self.baseline)
        self.assertEqual(entries[-1].name, 'addZero')
        self.assertFalse(entries[-1].checked)
        self.assertRejected('unchecked')
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace('- [ ] addZero', '- [x] addZero'))
        self.commit()
        with self.assertRaisesRegex(contract.ContractError, 'unapproved'):
            contract.validate_plan(self.app, self.baseline)

    def test_explicit_node_target_need_not_match_filename_globs(self):
        self.git('mv', 'calc.test.js', 'checks.js')
        for name in ('failed-test.md', 'AGENTS.md'):
            self.write(name, (self.app/name).read_text().replace('calc.test.js', 'checks.js'))
        self.header = self.header.replace('calc.test.js', 'checks.js')
        self.write('checks.js', self.header)
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.write('calc.js', 'export const add = (a,b) => a+b;\n')
        self.write('checks.js', self.header+self.code)
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace('- [ ]', '- [x]'))
        self.commit()
        self.assertIn('addAdds: positive sum', contract.gate(self.app, self.baseline).passed)

    def test_npm_test_uses_real_tap_and_script_is_frozen(self):
        self.write('AGENTS.md', '- Test: `npm test`\n')
        self.write('package.json', '{"type":"module","scripts":{"test":"node --test calc.test.js"}}\n')
        self.commit()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.green()
        self.assertIn('addAdds: positive sum', contract.gate(self.app, self.baseline).passed)
        self.write('package.json', '{"type":"module","scripts":{"test":"node --test unrelated.test.js"}}\n')
        self.commit()
        self.assertRejected('approved')

    def test_real_assertion_failure_is_red_with_named_evidence(self):
        self.write('calc.test.js', self.header+self.code)
        with self.assertRaises(contract.TestFailure) as error:
            contract.run_suite(self.app)
        self.assertIn('addAdds: positive sum', error.exception.result.failed)

    def test_syntax_error_is_infrastructure_not_behavioral_red(self):
        self.write('calc.test.js', 'this is not valid JavaScript !!!\n')
        with self.assertRaises(contract.ContractError) as error:
            contract.run_suite(self.app)
        self.assertNotIsInstance(error.exception, contract.TestFailure)
        self.assertIn('infrastructure', str(error.exception))
        self.assertIsInstance(error.exception, contract.BuildFailure)

    def test_suite_sigint_terminates_its_separate_process_group(self):
        marker = self.app/'suite-pid'
        self.write('calc.test.js', "const fs = require('node:fs');\nfs.writeFileSync(process.env.SOBAYA_CANCEL_MARKER, String(process.ppid));\nsetInterval(() => {}, 1000);\n")
        self.write('package.json', '{}\n')
        code = "import sys; sys.dont_write_bytecode=True; sys.path.insert(0,sys.argv[2]); import contract; contract.run_suite(sys.argv[1])"
        process = subprocess.Popen([sys.executable, '-c', code, str(self.app), str(MODULE.parent)], stdout=subprocess.PIPE, stderr=subprocess.PIPE, env=dict(os.environ, SOBAYA_CANCEL_MARKER=str(marker)), start_new_session=True)
        child = None
        try:
            deadline = time.monotonic()+5
            while not marker.exists() and process.poll() is None and time.monotonic() < deadline:
                time.sleep(0.02)
            self.assertTrue(marker.exists(), 'test process did not start')
            child = int(marker.read_text())
            process.send_signal(signal.SIGINT)
            process.communicate(timeout=5)
            with self.assertRaises(ProcessLookupError):
                os.kill(child, 0)
        finally:
            if process.poll() is None:
                process.kill()
                process.communicate()
            if child:
                try:
                    os.killpg(child, signal.SIGKILL)
                except ProcessLookupError:
                    pass

    def test_runner_timeout_is_not_red(self):
        self.write('calc.test.js', self.header+"test('hang', async () => { await new Promise(() => {}); });\nsetInterval(() => {}, 1000);\n")
        with self.assertRaisesRegex(contract.ContractError, 'timed out') as error:
            contract.run_suite(self.app, timeout=0.2)
        self.assertNotIsInstance(error.exception, contract.TestFailure)

    def test_runner_side_effect_cannot_leave_gate_green(self):
        self.green()
        self.write('calc.js', "import {writeFileSync} from 'node:fs';\nwriteFileSync('leftover.txt','side effect');\nexport const add = (a,b) => a+b;\n")
        self.commit()
        self.assertRejected('clean')

    def test_checked_entry_cannot_be_unchecked(self):
        self.green()
        self.baseline = self.git('rev-parse', 'HEAD')
        self.write('failed-test.md', (self.app/'failed-test.md').read_text().replace('- [x]', '- [ ]'))
        self.commit()
        with self.assertRaisesRegex(contract.ContractError, 'completed'):
            contract.validate_plan(self.app, self.baseline)

    def test_missing_baseline_does_not_default_to_head(self):
        self.green()
        with self.assertRaisesRegex(contract.ContractError, 'no approved baseline'):
            contract.saved_baseline(self.app)

    def test_legacy_loop_file_is_not_explicit_approval(self):
        self.green()
        (contract.git_dir(self.app)/'sobaya-loop-start').write_text(self.baseline)
        with self.assertRaisesRegex(contract.ContractError, 'no approved baseline'):
            contract.saved_baseline(self.app)

    def test_corrupt_state_does_not_fall_back_to_legacy(self):
        self.green()
        metadata = contract.git_dir(self.app)
        (metadata/'sobaya').mkdir()
        (metadata/'sobaya/state.json').write_text('{bad')
        (metadata/'sobaya-loop-start').write_text(self.baseline)
        with self.assertRaisesRegex(contract.ContractError, 'invalid approval state'):
            contract.saved_baseline(self.app)

    def test_linked_worktree_and_state_baseline_supported(self):
        self.green()
        worktree = self.app/'linked'
        self.git('worktree', 'add', '-q', '-b', 'linked', str(worktree))
        # A nested worktree appears untracked in its parent, but is independent itself.
        state = contract.git_dir(worktree)/'sobaya/state.json'
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_text(json.dumps({'baseline': self.baseline}))
        result = subprocess.run(['bash', str(MODULE.parents[1]/'bin/gate.sh'), str(worktree)], text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout+result.stderr)
        self.assertIn('PASS', result.stdout)


@unittest.skipUnless(shutil.which('go'), 'Go toolchain is optional')
class GoRunnerTests(unittest.TestCase):
    def test_go_actual_pass_fail_and_compile_error_are_distinct(self):
        with tempfile.TemporaryDirectory(prefix='sobaya-go-contract-') as directory:
            app = Path(directory)
            (app/'AGENTS.md').write_text('- Test: `go test ./...`\n')
            (app/'go.mod').write_text('module fixture\n\ngo 1.22\n')
            (app/'calc.go').write_text('package calc\nfunc Add(a,b int) int { return a+b }\n')
            path = app/'calc_test.go'
            path.write_text('package calc\nimport "testing"\nfunc TestAdd(t *testing.T) { if Add(1,2) != 3 { t.Fatal("bad") } }\n')
            self.assertIn('TestAdd', contract.run_suite(app).passed)
            path.write_text(path.read_text().replace('!= 3', '!= 4'))
            with self.assertRaises(contract.TestFailure) as error:
                contract.run_suite(app)
            self.assertIn('TestAdd', error.exception.result.failed)
            path.write_text(path.read_text().replace('Add(1,2)', 'Missing(1,2)'))
            with self.assertRaises(contract.ContractError) as error:
                contract.run_suite(app)
            self.assertNotIsInstance(error.exception, contract.TestFailure)
            self.assertIsInstance(error.exception, contract.BuildFailure)
            self.assertIn('undefined:', error.exception.result.output)


@unittest.skipUnless(os.environ.get('SOBAYA_TEST_VITEST_ROOT'), 'set SOBAYA_TEST_VITEST_ROOT to an existing local installation')
class VitestRunnerTests(unittest.TestCase):
    def test_real_vitest_pass_failure_and_skip_evidence(self):
        source = Path(os.environ['SOBAYA_TEST_VITEST_ROOT'])
        with tempfile.TemporaryDirectory(prefix='sobaya-vitest-contract-') as directory:
            app = Path(directory)
            # Dependencies are read through symlinks; Vite caches stay in this
            # fixture's own node_modules directory rather than the source app.
            (app/'node_modules/.bin').mkdir(parents=True)
            (app/'node_modules/.bin/vitest').symlink_to(source/'node_modules/.bin/vitest')
            (app/'node_modules/vitest').symlink_to(source/'node_modules/vitest')
            (app/'AGENTS.md').write_text('- Test: `vitest run --maxWorkers=1`\n')
            (app/'package.json').write_text('{"type":"module"}\n')
            path = app/'calc.test.js'
            path.write_text("import {test,expect} from 'vitest';\ntest('addAdds', () => expect(1+2).toBe(3));\n")
            self.assertIn('addAdds', contract.run_suite(app).passed)
            path.write_text(path.read_text().replace('toBe(3)', 'toBe(4)'))
            with self.assertRaises(contract.TestFailure) as error:
                contract.run_suite(app)
            self.assertIn('addAdds', error.exception.result.failed)
            path.write_text(path.read_text().replace("test('addAdds'", "test.skip('addAdds'"))
            self.assertIn('addAdds', contract.run_suite(app).skipped)


class PlanParserTests(unittest.TestCase):
    def test_rejects_empty_duplicate_unclosed_and_missing_blocks(self):
        valid = '- [ ] TestAdd — sum\n```go\nfunc TestAdd(t *testing.T) {}\n```\n'
        for text in ['', '# Plan\n', '- [x] TestAdd\n', valid+valid, valid[:-4], '- [X] TestAdd\n```go\nfunc TestAdd(t *testing.T) {}\n```\n']:
            with self.subTest(text=text), self.assertRaises(contract.ContractError):
                contract.read_plan(text)

    def test_go_entry_fields(self):
        entry = contract.read_plan('## Add\n- [ ] TestAdd — sum\n```go\nfunc TestAdd(t *testing.T) {}\n```\n')[0]
        self.assertEqual((entry.name, entry.checked, entry.heading, entry.language), ('TestAdd', False, '## Add', 'go'))
        self.assertEqual(entry.code, 'func TestAdd(t *testing.T) {}\n')


if __name__ == '__main__':
    unittest.main()
