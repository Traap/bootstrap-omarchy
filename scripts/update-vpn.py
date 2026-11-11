#!/usr/bin/env python3
"""Update the flat snx-rs key=value file while retaining unrelated settings."""
import re
import sys

server, login, tunnel = sys.argv[1:]
if not re.fullmatch(r'[A-Za-z0-9_.:\[\]-]+', server):
    raise SystemExit('Invalid VPN server address')
if not re.fullmatch(r'[A-Za-z0-9_-]+', login) or tunnel not in ('ipsec', 'ssl'):
    raise SystemExit('Invalid VPN login or tunnel type')
settings = {'server-name': server, 'login-type': login, 'tunnel-type': tunnel,
            'ignore-server-cert': 'false'}
lines = sys.stdin.read().splitlines()
seen = set()
for line in lines:
    match = re.match(r'^\s*([\w-]+)\s*=', line)
    key = match[1] if match else None
    if key in settings:
        if key not in seen:
            print(f'{key}={settings[key]}')
            seen.add(key)
    else:
        print(line)
for key, value in settings.items():
    if key not in seen:
        print(f'{key}={value}')
if not lines:
    print('ike-persist=true\nport-knock=true')
