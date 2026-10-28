"""Validate and atomically install configured Atomator bundles."""
import argparse
from datetime import datetime, timezone
import hashlib
from functools import lru_cache
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import uuid

ROOT = Path(__file__).resolve().parents[1]
MANIFEST = '.site-configured.json'
STATE_FILES = ('hosts.txt', 'credentials.conf', 'watchdog_hosts.conf', 'wallpapers.txt',
               'mac_addresses.txt', 'known_hosts', '.site-settings.json')


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


@lru_cache(maxsize=256)
def check_shell_syntax(content):
    # Source and staged copies have identical bytes. Reuse that exact-content
    # validation within one installer process rather than spawning Bash twice.
    subprocess.run(['bash', '-n'], input=content, check=True, capture_output=True)


def safe_relative(name):
    p = Path(name)
    if not name or '\\' in name or p.is_absolute() or any(x in ('..', '.') for x in name.split('/')):
        raise ValueError('Invalid bundle path: ' + name)
    return p


def source_files(root):
    """Explicit package contents: never include inventories, keys, backups or local reports."""
    names = ['README.md', 'SITE_CONFIGURATION.md', 'CHANGELOG.md', 'LICENSE', 'NOTICE', 'VERSION', 'configure_site.py']
    paths = [root / name for name in names if (root / name).is_file()]
    paths += list(root.glob('*.sh'))
    for directory in ('lib', 'defaults'):
        paths += [p for p in (root / directory).rglob('*') if p.is_file() and '__pycache__' not in p.parts and p.suffix in ('.py', '.sh', '.conf')]
    for p in sorted(paths):
        if p.is_symlink() or any(parent.is_symlink() for parent in p.parents):
            raise ValueError('Source symlinks are not supported')
        yield p


def write_manifest(output):
    files = {p.relative_to(output).as_posix(): digest(p) for p in source_files(output)}
    files['run-configured.sh'] = digest(output / 'run-configured.sh')
    (output / MANIFEST).write_text(json.dumps({'configured': True, 'format': 2,
        'version': (output / 'VERSION').read_text().strip(), 'files': files}, indent=2) + '\n')


def validate(root):
    root = Path(root).absolute()
    if root.is_symlink():
        raise ValueError('Bundle root must not be a symlink')
    data = json.loads((root / MANIFEST).read_text())
    if data.get('format') != 2 or data.get('configured') is not True or not isinstance(data.get('files'), dict):
        raise ValueError('Expected a configured format-2 bundle; regenerate from source')
    required = {'quick_install.sh', 'menu.sh', 'update.sh', 'VERSION', 'run-configured.sh', 'lib/runtime.sh', 'lib/bundle.py'}
    if not required.issubset(data['files']):
        raise ValueError('Bundle is incomplete')
    for name, expected in data['files'].items():
        p = root / safe_relative(name)
        if p.is_symlink() or any(parent.is_symlink() for parent in p.parents if parent != root.parent):
            raise ValueError('Bundle symlinks are not supported')
        if not p.is_file() or digest(p) != expected:
            raise ValueError('Bundle checksum mismatch: ' + name)
        if p.suffix == '.sh':
            check_shell_syntax(p.read_bytes())
    if (root / 'VERSION').read_text().strip() != data['version']:
        raise ValueError('Bundle version does not match manifest')
    return data


def check_target(target, source):
    target = Path(target).absolute()
    if target.is_symlink() or any(p.is_symlink() for p in target.parents):
        raise ValueError('Install path must not contain symlinks')
    forbidden = {Path('/'), Path('/root'), Path('/home'), Path('/usr'), Path('/etc'), Path('/var'), Path('/tmp'), Path('/opt'), Path('/bin')}
    if target in forbidden or target == source or target in source.parents or source in target.parents:
        raise ValueError('Choose a dedicated install directory outside the bundle')
    if target.exists() and (not target.is_dir() or not (target / 'menu.sh').is_file()):
        raise ValueError('Existing target is not an Atomator installation')
    return target


def install(source, target):
    source = Path(source).absolute()
    data = validate(source)
    target = check_target(target, source)
    target.parent.mkdir(parents=True, exist_ok=True)
    # One installer at a time, including update/rollback. Never break another process's lock.
    lock = target.parent / ('.' + target.name + '.install-lock')
    try:
        lock.mkdir(mode=0o700)
    except FileExistsError as exc:
        raise ValueError('Another install is active, or a previous install lock needs inspection: ' + str(lock)) from exc
    stage = None
    backup = None
    moved = False
    runtime_lock = None
    try:
        import fcntl
        lock_path = target.parent / ('.' + target.name + '.runtime-lock')
        runtime_lock = os.open(lock_path, os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW, 0o600)
        try:
            fcntl.flock(runtime_lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as exc:
            raise ValueError('A fleet job is active. Finish it before installing or rolling back.') from exc
        stage = Path(tempfile.mkdtemp(prefix='.' + target.name + '.stage-', dir=target.parent))
        if target.exists():
            if any(p.is_symlink() for p in target.rglob('*')):
                raise ValueError('Existing install contains symlinks; inspect before updating')
            shutil.copytree(target, stage, dirs_exist_ok=True)
        for name in data['files']:
            destination = stage / safe_relative(name)
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(source / name, destination)
            destination.chmod(0o700 if destination.suffix == '.sh' else 0o600)
        shutil.copyfile(source / MANIFEST, stage / MANIFEST)
        # Runtime data always comes from the existing installation when present.
        for name in STATE_FILES:
            destination = stage / name
            if not destination.exists() and (source / name).is_file():
                shutil.copyfile(source / name, destination)
        for name in ('hosts.txt', 'credentials.conf', 'watchdog_hosts.conf', 'wallpapers.txt'):
            destination = stage / name
            if not destination.exists():
                shutil.copyfile(stage / 'defaults' / name.replace('.txt', '.conf'), destination)
            destination.chmod(0o600)
        (stage / 'version.txt').write_text(data['version'] + '\n' + datetime.now(timezone.utc).isoformat() + '\n')
        for name in (MANIFEST, '.site-settings.json', 'known_hosts', 'mac_addresses.txt'):
            if (stage / name).exists():
                (stage / name).chmod(0o600)
        stage.chmod(0o700)
        validate(stage)
        if target.exists():
            backup_root = target.parent / (target.name + '.backups')
            backup_root.mkdir(mode=0o700, exist_ok=True)
            if backup_root.is_symlink():
                raise ValueError('Backup directory must not be a symlink')
            backup_root.chmod(0o700)
            backup = backup_root / (datetime.now(timezone.utc).strftime('%Y%m%dT%H%M%SZ') + '-' + uuid.uuid4().hex[:8])
            target.rename(backup)
            moved = True
        try:
            stage.rename(target)
            stage = None
        except OSError:
            if moved:
                backup.rename(target)
                moved = False
            raise
        print('Installed Atomator ' + data['version'] + ' in ' + str(target))
        if backup:
            print('Previous installation preserved in ' + str(backup))
        return target
    finally:
        if stage and stage.exists():
            shutil.rmtree(stage)
        if runtime_lock is not None:
            os.close(runtime_lock)
        lock.rmdir()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('operation', choices=['validate', 'install', 'package'])
    parser.add_argument('--source', type=Path, default=ROOT)
    parser.add_argument('--target', type=Path, default=Path('/remote_tools'))
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    try:
        if args.operation == 'validate':
            print('Validated bundle ' + validate(args.source)['version'])
        elif args.operation == 'install':
            install(args.source, args.target)
        else:
            validate(args.source)
            if not args.output or args.output.exists():
                raise ValueError('Choose a new --output archive path')
            import tarfile
            data = validate(args.source)
            with tarfile.open(args.output, 'x:gz') as archive:
                directory = tarfile.TarInfo('atomator')
                directory.type = tarfile.DIRTYPE
                directory.mode = 0o700
                archive.addfile(directory)
                for name in [*data['files'], MANIFEST]:
                    archive.add(args.source / name, arcname='atomator/' + name, recursive=False)
            print('Created ' + str(args.output) + '. Local credentials, host lists and site-settings are excluded.')
        return 0
    except (OSError, ValueError, subprocess.CalledProcessError) as exc:
        print('Bundle error: ' + str(exc), file=__import__('sys').stderr)
        return 1


if __name__ == '__main__':
    raise SystemExit(main())
