import importlib.util
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('configure_site', ROOT / 'configure_site.py')
site = importlib.util.module_from_spec(spec)
spec.loader.exec_module(site)

class ConfigurationTests(unittest.TestCase):
    def test_all_shell_templates_parse_and_are_inert(self):
        scripts = [p for p in ROOT.rglob('*') if p.is_file() and '.git' not in p.parts and (p.suffix == '.sh' or p.read_bytes().startswith((b'#!/bin/bash', b'#!/bin/sh', b'#!/usr/bin/env bash')))]
        for script in scripts:
            with self.subTest(script=str(script.relative_to(ROOT))):
                subprocess.run(['bash', '-n', str(script)], check=True, capture_output=True)
                env = {k: v for k, v in os.environ.items() if k != 'SITE_CONFIGURATION_CONFIRMED'}
                result = subprocess.run(['bash', str(script)], env=env, capture_output=True, timeout=5)
                self.assertEqual(result.returncode, 64)

    def test_empty_or_injected_configuration_is_rejected(self):
        with tempfile.TemporaryDirectory() as tmp:
            config = Path(tmp) / 'settings.json'
            for value in ['', 'host; touch /tmp/not-allowed', 'example.invalid', '192.0.2.10']:
                config.write_text(json.dumps({'replacements': {key: value for key in site.tokens()}}))
                with self.assertRaises(ValueError): site.settings(config)

    def test_configure_without_executing_preserves_legal_files(self):
        with tempfile.TemporaryDirectory() as tmp:
            values = {key: (f'10.254.254.{i+1}' if key.startswith('192.') else 'VALIDATION.TEST' if key.isupper() else 'validation.test' if '.' in key else 'validationuser') for i, key in enumerate(site.tokens())}
            config = Path(tmp) / 'settings.json'
            config.write_text(json.dumps({'replacements': values}))
            output = site.configure(config, Path(tmp) / 'bundle')
            self.assertTrue((output / '.site-configured.json').exists())
            for script in output.rglob('*.sh'):
                subprocess.run(['bash', '-n', str(script)], check=True, capture_output=True)
            for name in ['LICENSE', 'NOTICE']:
                if (ROOT / name).exists(): self.assertEqual((ROOT / name).read_bytes(), (output / name).read_bytes())
            with self.assertRaises(ValueError): site.configure(config, output)

if __name__ == '__main__': unittest.main()
