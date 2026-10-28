"""Create and optionally run an explicitly configured deployment bundle. No network I/O."""
import argparse
import ipaddress
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from lib.bundle import source_files, write_manifest

ROOT = Path(__file__).resolve().parent
TARGET = re.compile(r'(?<![\w.-])(?:[\w-]+\.)*example\.invalid\b|(?<![\d.])192\.0\.2\.\d{1,3}(?![\d.])|\b(?:exampleuser|examplestorageadmin)\b', re.I)

def tokens():
    return sorted({m.group(0) for p in ROOT.rglob('*.sh') if '.git' not in p.parts for m in TARGET.finditer(p.read_text(encoding='utf-8'))})

def settings(path):
    data = json.loads(Path(path).read_text(encoding='utf-8'))
    if not isinstance(data, dict):
        raise ValueError('Configuration must be an object')
    replacements = data.get('replacements', {})
    required = tokens()
    if not isinstance(replacements, dict) or set(replacements) != set(required):
        raise ValueError('Configuration keys must exactly match --schema output')
    for key, value in replacements.items():
        if not isinstance(value, str) or not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9_.:-]*', value):
            raise ValueError('Every replacement must be an explicit hostname, address or account without shell syntax')
        if 'example.' in value.lower() or value.lower().endswith('.invalid') or value == 'exampleuser':
            raise ValueError('Documentation placeholders cannot be deployed')
        if key.lower() != key and 'example.invalid' in key.lower():
            if value != value.upper(): raise ValueError('Realm must be uppercase')
        if key.startswith('192.0.2.'):
            address = ipaddress.ip_address(value)
            if address in ipaddress.ip_network('192.0.2.0/24'):
                raise ValueError('Documentation addresses cannot be deployed')
    return replacements

def configure(config, output):
    replacements = settings(config)
    output = Path(output).resolve()
    if output.exists() or output == ROOT or ROOT in output.parents:
        raise ValueError('Choose a new output directory outside the source checkout')
    output.mkdir(parents=True, mode=0o700)
    for p in source_files(ROOT):
        relative = p.relative_to(ROOT)
        if any(part in ('.git', '__pycache__', '.github') for part in relative.parts) or p.is_dir(): continue
        if p.is_symlink(): raise ValueError('Source symlinks are not supported')
        destination = output / relative
        destination.parent.mkdir(parents=True, exist_ok=True)
        raw = p.read_bytes()
        try: text = raw.decode('utf-8')
        except UnicodeDecodeError: destination.write_bytes(raw); continue
        if p.name not in ('configure_site.py', 'site-settings.example.json', 'LICENSE', 'NOTICE'):
            for key in sorted(replacements, key=len, reverse=True):
                text = re.sub(r'(?<![\w.-])' + re.escape(key) + r'(?![\w.-])', lambda _: replacements[key], text)
        if p.suffix == '.sh':
            text = text.replace('\n', '\n# SITE_BUNDLE_CONFIGURED=1\n', 1)
        destination.write_text(text, encoding='utf-8', newline='\n')
        destination.chmod(0o700 if p.suffix == '.sh' else 0o600)
    shutil.copyfile(config, output / '.site-settings.json')
    (output / '.site-settings.json').chmod(0o600)
    (output / 'run-configured.sh').write_text('#!/bin/bash\nset -euo pipefail\nexport SITE_CONFIGURATION_CONFIRMED=1\ncd -- "$(dirname -- "${BASH_SOURCE[0]}")"\nexec bash "$@"\n', encoding='utf-8', newline='\n')
    (output / 'run-configured.sh').chmod(0o700)
    write_manifest(output)
    return output

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--schema', action='store_true')
    parser.add_argument('--config')
    parser.add_argument('--output')
    parser.add_argument('--run', nargs=argparse.REMAINDER)
    args = parser.parse_args()
    try:
        if args.schema:
            print(json.dumps({'replacements': {key: '' for key in tokens()}}, indent=2)); return 0
        if not args.config or not args.output: raise ValueError('--config and --output are required')
        output = configure(args.config, args.output)
        print('Configured bundle created. No connection was made.')
        if args.run:
            script = (output / args.run[0]).resolve()
            if output not in script.parents or not script.is_file() or script.suffix != '.sh': raise ValueError('Choose a shell script inside the configured bundle')
            env = dict(os.environ, SITE_CONFIGURATION_CONFIRMED='1')
            return subprocess.run(['bash', str(script), *args.run[1:]], cwd=output, env=env).returncode
        return 0
    except (ValueError, OSError, json.JSONDecodeError) as exc:
        print('Configuration error: ' + str(exc), file=sys.stderr); return 64

if __name__ == '__main__':
    raise SystemExit(main())
