#!/usr/bin/env python3
"""Render the bundled gits collection using the configured absolute root."""
import json
from pathlib import Path
import re
import sys

root = Path(sys.argv[2])
if not root.is_absolute():
    raise SystemExit('cloneRoot must be an absolute path')
content = Path(sys.argv[1]).read_text()
content, count = re.subn(r'(?m)^(\s*- root_dir:).*$', lambda m: m[1] + ' ' + json.dumps(str(root)), content)
if count != 1:
    raise SystemExit('Expected exactly one root_dir in the bundled repository locations')
sys.stdout.write(content)
