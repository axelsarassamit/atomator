"""Download a pinned GitHub revision, configure locally, then use the bundle installer."""
import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REPOSITORY = 'https://github.com/axelsarassamit/atomator.git'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--target', type=Path, default=ROOT)
    parser.add_argument('--yes', action='store_true')
    args = parser.parse_args()
    settings = ROOT / '.site-settings.json'
    if not settings.is_file():
        print('Local site settings are unavailable. Create a new configured bundle and update with --bundle.', file=sys.stderr)
        return 64
    try:
        revision = subprocess.check_output(['git', 'ls-remote', REPOSITORY, 'refs/heads/main'], text=True, timeout=60).split()[0]
        if not re.fullmatch('[0-9a-f]{40}', revision):
            raise ValueError('Could not resolve the update revision')
        print('GitHub source revision: ' + revision, flush=True)
        with tempfile.TemporaryDirectory(prefix='atomator-update-') as tmp:
            source = Path(tmp) / 'source'
            source.mkdir()
            for command in (['git', 'init', '-q', str(source)],
                            ['git', '-C', str(source), 'fetch', '--depth=1', REPOSITORY, revision],
                            ['git', '-C', str(source), 'checkout', '-q', '--detach', 'FETCH_HEAD']):
                subprocess.run(command, check=True, timeout=120)
            bundle = Path(tmp) / 'configured'
            subprocess.run([sys.executable, str(source / 'configure_site.py'), '--config', str(settings), '--output', str(bundle)], check=True, timeout=120)
            command = ['bash', str(bundle / 'run-configured.sh'), 'quick_install.sh', '--target', str(args.target), '--skip-dependencies']
            if args.yes:
                command.append('--yes')
            return subprocess.run(command).returncode
    except (OSError, ValueError, IndexError, subprocess.SubprocessError) as exc:
        print('Update failed: ' + str(exc), file=sys.stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
