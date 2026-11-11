#!/usr/bin/env python3
"""Add SSSD lookup without removing existing providers or action clauses."""
import re
import sys

seen = set()
for line in sys.stdin:
    match = re.match(r'^(passwd|group)(\s*:\s*)(.*?)(\n?)$', line)
    if match:
        name, separator, body, _ = match.groups()
        seen.add(name)
        providers, marker, comment = body.partition('#')
        if not re.search(r'\bsss\b', providers):
            providers = providers.rstrip() + ' sss '
        line = name + separator + providers.rstrip()
        if marker:
            line += ' #' + comment
        line += '\n'
    sys.stdout.write(line)
for name in ('passwd', 'group'):
    if name not in seen:
        raise SystemExit(f'Missing {name} entry in nsswitch.conf')
