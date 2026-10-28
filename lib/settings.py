"""Parse local configuration as data, never as shell code."""
import argparse
import ipaddress
from pathlib import Path
import re
import shlex
import sys


def host(value):
    if not value or len(value) > 253 or value.startswith('-'):
        raise ValueError('Invalid host: ' + value)
    try:
        ipaddress.ip_address(value)
    except ValueError:
        if re.fullmatch(r'[0-9.]+', value) or not all(
            re.fullmatch(r'[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?', label)
            for label in value.rstrip('.').split('.')
        ):
            raise ValueError('Invalid host: ' + value)
    return value


def inventory(path):
    result = []
    for line in Path(path).read_text(encoding='utf-8').splitlines():
        value = line.split('#', 1)[0].strip()
        if value and host(value) not in result:
            result.append(value)
    if not result:
        raise ValueError('Host inventory is empty')
    return result


def address_range(value):
    match = re.fullmatch(r'((?:[0-9]{1,3}\.){3})([0-9]{1,3})-([0-9]{1,3})', value)
    if not match:
        raise ValueError('Use an IPv4 range such as 10.0.0.10-30')
    base, first, last = match.groups()
    ipaddress.IPv4Address(base + first)
    ipaddress.IPv4Address(base + last)
    if int(first) > int(last):
        raise ValueError('Range end must not precede the start')
    return [base + str(number) for number in range(int(first), int(last) + 1)]


def config(path, allowed):
    result = {}
    if not Path(path).exists():
        return result
    for number, line in enumerate(Path(path).read_text(encoding='utf-8').splitlines(), 1):
        line = line.strip()
        if not line or line.startswith('#'):
            continue
        key, sep, value = line.partition('=')
        key, value = key.strip(), value.strip()
        if not sep or key not in allowed or key in result:
            raise ValueError(f'Invalid or duplicate configuration key on line {number}')
        if value.startswith(('"', "'")):
            parts = shlex.split(value, comments=False)
            if len(parts) != 1:
                raise ValueError(f'Invalid quoted value on line {number}')
            value = parts[0]
        if '\x00' in value or '\n' in value or '\r' in value:
            raise ValueError('Configuration values must be single lines')
        result[key] = value
    return result


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('kind', choices=['host', 'hosts', 'range', 'credentials', 'watchdog', 'dns'])
    parser.add_argument('value')
    args = parser.parse_args()
    try:
        if args.kind == 'host':
            print(host(args.value))
        elif args.kind == 'range':
            print('\n'.join(address_range(args.value)))
        elif args.kind == 'hosts':
            print('\n'.join(inventory(args.value)))
        elif args.kind == 'dns':
            for value in args.value.split():
                ipaddress.ip_address(value)
        else:
            keys = ['SSH_USER', 'SSH_PASSWORD', 'SSH_PASS', 'SSH_IDENTITY_FILE', 'SSH_PORT'] if args.kind == 'credentials' else ['HOST_1', 'HOST_2', 'HOST_3']
            values = config(args.value, keys)
            if args.kind == 'watchdog':
                for value in values.values():
                    if value:
                        host(value)
            sys.stdout.buffer.write(b'\0'.join(values.get(key, '').encode() for key in keys) + b'\0')
        return 0
    except (ValueError, OSError) as exc:
        print(str(exc), file=sys.stderr)
        return 64


if __name__ == '__main__':
    raise SystemExit(main())
