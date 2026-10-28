"""Offline integration tests: fake SSH/SCP only, temporary installation targets."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import tempfile
import unittest

from lib import bundle
from lib.settings import address_range
import configure_site as site

ROOT = Path(__file__).resolve().parents[1]


def configured(output):
    values = {key: (f'10.254.254.{i + 1}' if key.startswith('192.') else
                   'VALIDATION.TEST' if key.isupper() else
                   'validation.test' if '.' in key else 'validationuser') for i, key in enumerate(site.tokens())}
    settings = output.parent / 'settings.json'
    settings.write_text(json.dumps({'replacements': values}))
    return site.configure(settings, output)


class BundleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.source = configured(cls.root / 'source')

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def test_every_menu_action_is_shipped(self):
        references = re.findall(r'run_script "([^"]+)"', (ROOT / 'menu.sh').read_text())
        for name in references:
            self.assertTrue((self.source / name).is_file(), name)
        bundle.validate(self.source)

    def test_host_ranges_reject_invalid_octets_or_reverse_ranges(self):
        self.assertEqual(address_range('10.0.0.1-3'), ['10.0.0.1', '10.0.0.2', '10.0.0.3'])
        for value in ('10.0.0.1-999', '10.0.0.9-1', '999.0.0.1-3', '10.0.0.1-3; touch /tmp/invalid'):
            with self.subTest(value=value), self.assertRaises(ValueError):
                address_range(value)

    def test_destructive_watchdog_payloads_are_preserved_verbatim(self):
        expected = 'f61f3ad0400cac30cc231e4c7a358cf7b4469075a589f85bd172470d2dbeb91c'
        for name in ('install_connectivity_watchdog.sh', 'install_server_watchdog.sh'):
            text = (ROOT / name).read_text()
            payload = text[text.index('cat > "$LOCAL_SCRIPT" << '):].split('\n', 1)[1].split('\nSCRIPT', 1)[0]
            self.assertEqual(hashlib.sha256(payload.encode()).hexdigest(), expected, name)

    def test_install_update_and_rollback_preserve_state_and_match_source(self):
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'installed'
            bundle.install(self.source, target)
            saved = {'credentials.conf': "SSH_USER='operator'\nSSH_PASS='old secret'\n",
                     'hosts.txt': 'good.test\nbad.test\n', 'known_hosts': 'verified host keys\n',
                     'watchdog_hosts.conf': 'HOST_1=ping1.test\nHOST_2=ping2.test\nHOST_3=\n'}
            for name, content in saved.items():
                (target / name).write_text(content)
            (target / 'reports').mkdir()
            (target / 'reports' / 'keep.txt').write_text('prior results')
            bundle.install(self.source, target)
            backup = next((Path(tmp) / 'installed.backups').iterdir())
            bundle.install(backup, target)
            for name, content in saved.items():
                self.assertEqual((target / name).read_text(), content)
            self.assertEqual((target / 'reports' / 'keep.txt').read_text(), 'prior results')
            for name in bundle.validate(self.source)['files']:
                self.assertEqual((target / name).read_bytes(), (self.source / name).read_bytes(), name)

    def test_bad_bundle_never_replaces_install(self):
        with tempfile.TemporaryDirectory() as tmp:
            target, damaged = Path(tmp) / 'target', Path(tmp) / 'damaged'
            bundle.install(self.source, target)
            shutil.copytree(self.source, damaged)
            (damaged / 'menu.sh').write_text('#!/bin/bash\nexit 0\n')
            before = (target / 'menu.sh').read_bytes()
            with self.assertRaises(ValueError):
                bundle.install(damaged, target)
            self.assertEqual((target / 'menu.sh').read_bytes(), before)
            self.assertFalse((target.parent / '.target.install-lock').exists())

    def test_failed_activation_restores_previous_install(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'target'
            bundle.install(self.source, target)
            (target / 'hosts.txt').write_text('retained.test\n')
            rename = Path.rename
            def fail_activation(path, destination):
                if path.name.startswith('.target.stage-'):
                    raise OSError('Simulated activation failure')
                return rename(path, destination)
            with patch.object(Path, 'rename', fail_activation):
                with self.assertRaises(OSError):
                    bundle.install(self.source, target)
            self.assertEqual((target / 'hosts.txt').read_text(), 'retained.test\n')
            bundle.validate(target)

    def test_install_refuses_active_jobs_and_concurrent_installers(self):
        import fcntl
        with tempfile.TemporaryDirectory() as tmp:
            target = Path(tmp) / 'target'
            lock = Path(tmp) / '.target.runtime-lock'
            with lock.open('w') as stream:
                fcntl.flock(stream, fcntl.LOCK_SH | fcntl.LOCK_NB)
                with self.assertRaisesRegex(ValueError, 'fleet job'):
                    bundle.install(self.source, target)
            self.assertFalse(target.exists())
            (Path(tmp) / '.target.install-lock').mkdir()
            with self.assertRaisesRegex(ValueError, 'install is active'):
                bundle.install(self.source, target)

    def test_update_propagates_installer_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            broken = Path(tmp) / 'broken'
            shutil.copytree(self.source, broken)
            (broken / 'quick_install.sh').write_text('#!/bin/bash\nexit 42\n')
            bundle.write_manifest(broken)
            env = dict(os.environ, SITE_CONFIGURATION_CONFIRMED='1')
            result = subprocess.run(['bash', str(self.source / 'update.sh'), '--bundle', str(broken), '--yes', '--target', str(Path(tmp) / 'target')], env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 42, result.stderr)
            self.assertNotIn('Update complete.', result.stdout)

    def test_archive_excludes_local_data(self):
        with tempfile.TemporaryDirectory() as tmp:
            source = Path(tmp) / 'source'
            shutil.copytree(self.source, source)
            (source / 'credentials.conf').write_text('SSH_PASS=private\n')
            (source / 'hosts.txt').write_text('private.test\n')
            archive = Path(tmp) / 'package.tar.gz'
            subprocess.run(['python3', str(source / 'lib/bundle.py'), 'package', '--output', str(archive)], check=True, capture_output=True)
            with tarfile.open(archive) as tf:
                names = tf.getnames()
                self.assertNotIn('atomator/credentials.conf', names)
                self.assertNotIn('atomator/hosts.txt', names)
                self.assertNotIn('atomator/.site-settings.json', names)
                extract = Path(tmp) / 'extracted'
                tf.extractall(extract, filter='data')
            bundle.validate(extract / 'atomator')

    def test_download_pins_a_revision_and_installs_only_after_configuration(self):
        # The fake Git executable copies the local source. No GitHub/network access.
        with tempfile.TemporaryDirectory() as tmp:
            tmp = Path(tmp)
            binaries = tmp / 'bin'
            binaries.mkdir()
            git = binaries / 'git'
            git.write_text('''#!/usr/bin/env python3
import json, os, shutil, sys
args = sys.argv[1:]
with open(os.environ['FAKE_GIT_LOG'], 'a') as stream:
    stream.write(json.dumps(args) + '\\n')
if args[0] == 'ls-remote':
    print('a' * 40 + '\\trefs/heads/main')
elif args[0] == 'init':
    shutil.copytree(os.environ['FAKE_GIT_SOURCE'], args[-1], dirs_exist_ok=True, ignore=shutil.ignore_patterns('.git', '__pycache__'))
elif 'fetch' in args:
    assert args[-1] == 'a' * 40
elif 'checkout' in args:
    assert args[-2:] == ['--detach', 'FETCH_HEAD']
else:
    sys.exit(99)
''')
            git.chmod(0o700)
            log = tmp / 'git.jsonl'
            target = tmp / 'target'
            env = dict(os.environ, PATH=str(binaries) + os.pathsep + os.environ['PATH'],
                       FAKE_GIT_LOG=str(log), FAKE_GIT_SOURCE=str(ROOT))
            result = subprocess.run(['python3', str(self.source / 'lib/update_bundle.py'), '--target', str(target), '--yes'],
                                    env=env, capture_output=True, text=True, timeout=120)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            bundle.validate(target)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(len(calls), 4)
            self.assertIn('a' * 40, result.stdout)
            self.assertEqual((target / 'menu.sh').read_bytes(), (self.source / 'menu.sh').read_bytes())

    def test_unsafe_target_and_symlinks_rejected(self):
        for target in ('/', '/root', '/etc', str(self.source), str(self.source / 'child')):
            with self.subTest(target=target), self.assertRaises(ValueError):
                bundle.check_target(Path(target), self.source)
        with tempfile.TemporaryDirectory() as tmp:
            linked = Path(tmp) / 'link'
            linked.symlink_to(self.source, target_is_directory=True)
            with self.assertRaises(ValueError):
                bundle.validate(linked)


class FleetTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temp = tempfile.TemporaryDirectory()
        cls.root = Path(cls.temp.name)
        cls.template = configured(cls.root / 'template')
        cls.bin = cls.root / 'bin'
        cls.bin.mkdir()
        stub = '''#!/usr/bin/env python3
import json, os, sys, time
from pathlib import Path
args = sys.argv[1:]
if Path(sys.argv[0]).name == 'sshpass':
    os.execvp(args[1], args[1:])
host = next((x.split('@', 1)[1] for x in args if '@' in x), '')
data = sys.stdin.read()
with open(os.environ['FAKE_SSH_LOG'], 'a') as stream:
    stream.write(json.dumps({'args': args, 'stdin': data, 'password': os.environ.get('SSHPASS')}) + '\\n')
if os.environ.get('FAKE_SLOW') and os.environ['FAKE_SLOW'] in host:
    time.sleep(3)
if os.environ.get('FAKE_FAIL') and os.environ['FAKE_FAIL'] in host:
    print('fake SSH authentication failed', file=sys.stderr)
    sys.exit(255)
print('test-host')
'''
        for name in ('ssh', 'scp', 'sshpass', 'ping'):
            path = cls.bin / name
            path.write_text(stub)
            path.chmod(0o700)

    @classmethod
    def tearDownClass(cls):
        cls.temp.cleanup()

    def setUp(self):
        self.work = tempfile.TemporaryDirectory()
        self.addCleanup(self.work.cleanup)
        self.path = Path(self.work.name)
        self.source = self.path / 'bundle'
        shutil.copytree(self.template, self.source)
        (self.source / 'hosts.txt').write_text(' # comment\ngood.test\nbad.test # comment\ngood.test\n')
        (self.source / 'credentials.conf').write_text('SSH_USER=operator\nSSH_PASS=legacy-password\n')
        self.log = self.path / 'calls.jsonl'
        self.env = {k: v for k, v in os.environ.items() if k not in ('SSH_USER', 'SSH_PASSWORD', 'SSH_PASS', 'SSH_PORT', 'SSH_IDENTITY_FILE', 'MAX_PARALLEL', 'ATOMATOR_TIMEOUT', 'ATOMATOR_KNOWN_HOSTS')}
        self.env.update(PATH=str(self.bin) + os.pathsep + os.environ['PATH'],
                        SITE_CONFIGURATION_CONFIRMED='1', FAKE_SSH_LOG=str(self.log), FAKE_FAIL='bad.test')

    def run_action(self, action='update_all.sh', args=(), input=''):
        return subprocess.run(['bash', str(self.source / action), '--yes', *args], input=input, env=self.env, capture_output=True, text=True, timeout=20)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def latest(self):
        return sorted((self.source / 'reports').iterdir())[-1]

    def test_partial_failure_is_nonzero_with_per_host_errors_and_retry(self):
        result = self.run_action()
        self.assertEqual(result.returncode, 1, result.stderr)
        run = self.latest()
        self.assertIn('good.test\tOK\t0', (run / 'results.tsv').read_text())
        self.assertIn('bad.test\tFAILED\t255', (run / 'results.tsv').read_text())
        self.assertIn('authentication failed', (run / 'errors/bad.test.log').read_text())
        failed = run / 'failed-hosts.txt'
        self.assertEqual(failed.read_text(), 'bad.test\n')
        self.log.unlink()
        self.env['FAKE_FAIL'] = ''
        retry = self.run_action(args=['--retry-failed', str(failed)])
        self.assertEqual(retry.returncode, 0, retry.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assertIn('operator@bad.test', self.calls()[0]['args'])

    def test_legacy_password_is_used_without_shell_interpolation_and_host_keys_are_strict(self):
        self.run_action(args=['--host', 'good.test'])
        call = self.calls()[0]
        self.assertEqual(call['password'], 'legacy-password')
        self.assertIn('StrictHostKeyChecking=yes', call['args'])
        self.assertNotIn('legacy-password', ' '.join(call['args']))
        self.assertIn('sudo -n', call['args'][-1])
        self.assertNotIn('sudo -S', call['args'][-1])

    def test_password_rotation_preserves_saved_credentials_on_partial_failure(self):
        secret = '''a'"$()`\\&/;| password'''
        original = (self.source / 'credentials.conf').read_bytes()
        result = self.run_action('change_password.sh', input=secret + '\n' + secret + '\nyes\n')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual((self.source / 'credentials.conf').read_bytes(), original)
        for call in self.calls():
            self.assertEqual(call['stdin'], 'operator:' + secret + '\n')
            self.assertNotIn(secret, ' '.join(call['args']))
        for path in (self.source / 'reports').rglob('*'):
            if path.is_file():
                self.assertNotIn(secret.encode(), path.read_bytes(), str(path))

    def test_custom_command_quotes_survive_unchanged_as_stdin(self):
        command = '''printf '%s\\n' "quote's and $HOME"'''
        result = self.run_action('run_remote_command.sh', ['--host', 'good.test'], input=command + '\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls()[0]['stdin'], command + '\n')
        self.assertNotIn(command, ' '.join(self.calls()[0]['args']))

    def test_preview_has_no_connections_or_report_side_effects(self):
        result = self.run_action(args=['--dry-run'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Hosts (2)', result.stdout)
        self.assertEqual(self.calls(), [])
        self.assertFalse((self.source / 'reports').exists())

    def test_operation_cancellation_is_distinct_from_failure(self):
        result = self.run_action('shutdown_all.sh', input='no\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls(), [])
        self.assertIn('CANCELLED', (self.latest() / 'results.tsv').read_text())
        self.assertEqual((self.latest() / 'failed-hosts.txt').read_text(), '')

    def test_invalid_inventory_selection_or_parallel_limit_stops_before_ssh(self):
        for args in (['--host', 'outside.test'], ['--host', 'good.test bad.test'], ['--parallel', '0'], ['--parallel', '999'], ['--hosts-file']):
            with self.subTest(args=args):
                self.assertEqual(self.run_action(args=args).returncode, 64)
        (self.source / 'hosts.txt').write_text('good.test; touch /tmp/not-allowed\n')
        self.assertEqual(self.run_action().returncode, 64)
        self.assertEqual(self.calls(), [])

    def test_timeout_is_a_reported_failure(self):
        self.env.update(FAKE_SLOW='good.test', ATOMATOR_TIMEOUT='1')
        result = self.run_action(args=['--host', 'good.test'])
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn('good.test\tFAILED\t124', (self.latest() / 'results.tsv').read_text())

    def test_key_auth_does_not_use_password_helper(self):
        (self.source / 'credentials.conf').write_text('SSH_USER=operator\n')
        result = self.run_action(args=['--host', 'good.test'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIsNone(self.calls()[0]['password'])
        self.assertIn('BatchMode=yes', self.calls()[0]['args'])

    def test_host_removal_matches_exact_entries_instead_of_regular_expressions(self):
        (self.source / 'hosts.txt').write_text('10.0.0.1\n10x0x0x1\nother.test\n')
        result = self.run_action('manage_hosts.sh', input='4\n10.0.0.1\n0\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual((self.source / 'hosts.txt').read_text(), '10x0x0x1\nother.test\n')
        self.assertEqual(self.calls(), [])

    def test_explicit_empty_password_uses_keys_and_root_payload_needs_no_sudo(self):
        self.env.update(SSH_USER='root', SSH_PASSWORD='')
        result = self.run_action('run_remote_command.sh', ['--host', 'good.test'], input='true\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        call = self.calls()[0]
        self.assertIsNone(call['password'])
        self.assertIn('BatchMode=yes', call['args'])
        self.assertEqual(call['args'][-1], 'bash -se --')

    def test_configuration_is_data_and_environment_overrides_legacy_alias(self):
        marker = self.path / 'must-not-exist'
        (self.source / 'credentials.conf').write_text(f'SSH_USER=operator\nSSH_PASS=$(touch {marker})\n')
        self.env['SSH_PASSWORD'] = 'explicit-password'
        result = self.run_action(args=['--host', 'good.test'])
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(marker.exists())
        self.assertEqual(self.calls()[0]['password'], 'explicit-password')

    def test_every_fleet_action_reaches_fake_transport_and_has_valid_remote_syntax(self):
        self.env['FAKE_FAIL'] = ''
        (self.source / 'watchdog_hosts.conf').write_text('HOST_1=ping1.test\nHOST_2=ping2.test\nHOST_3=\n')
        (self.source / 'wallpapers.txt').write_text('https://validation.test/wallpaper.jpg\n')
        inputs = {
            'change_dns.sh': '\n', 'fix_static_ip.sh': '\n',
            'change_password.sh': 'newpass\nnewpass\nyes\n',
            'run_remote_command.sh': 'printf "hello"\n',
            'change_watchdog_timer.sh': '72\nyes\n',
            'install_connectivity_watchdog.sh': 'yes\n',
            'install_server_watchdog.sh': 'yes\n',
            'reboot.sh': 'yes\n', 'shutdown_all.sh': 'yes\n',
            'install_package.sh': 'curl\n', 'check_internet.sh': 'https://validation.test\n',
            'copy_file_to_all.sh': str(self.source / 'README.md') + '\n/tmp/test-file\n',
            'send_message.sh': 'Test message\n',
        }
        for path in sorted(self.source.glob('*.sh')):
            if 'runtime_init "$@"' not in path.read_text() or path.name == 'monitor_watchdog_test_live.sh':
                continue
            with self.subTest(script=path.name):
                self.log.unlink(missing_ok=True)
                result = self.run_action(path.name, ['--host', 'good.test'], input=inputs.get(path.name, ''))
                self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
                calls = self.calls()
                self.assertTrue(calls, path.name + ' never reached fake SSH')
                for call in calls:
                    # Parse every transmitted shell command and payload without executing it.
                    subprocess.run(['bash', '-n', '-c', call['args'][-1]], check=True, capture_output=True)
                    if call['stdin'] and path.name not in ('change_password.sh', 'send_message.sh'):
                        subprocess.run(['bash', '-n'], input=call['stdin'], text=True, check=True, capture_output=True)

    def test_parallel_limit_is_respected(self):
        (self.source / 'hosts.txt').write_text('first.test\nsecond.test\nthird.test\n')
        self.env.update(FAKE_FAIL='', FAKE_SLOW='.test')
        import time
        started = time.monotonic()
        result = self.run_action(args=['--parallel', '2'])
        elapsed = time.monotonic() - started
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls()), 3)
        # Three 3-second jobs must require at least two worker batches.
        self.assertGreaterEqual(elapsed, 5.5)


if __name__ == '__main__':
    unittest.main()
