#!/usr/bin/env python3
"""Merge section/key/value arguments into an INI document from stdin."""
import configparser
import sys

config = configparser.ConfigParser(interpolation=None, strict=False)
config.optionxform = str
config.read_file(sys.stdin)
args = sys.argv[1:]
if len(args) % 3:
    raise SystemExit('Expected section/key/value triples')
for section, key, value in zip(args[::3], args[1::3], args[2::3]):
    if not config.has_section(section):
        config.add_section(section)
    config.set(section, key, value)
config.write(sys.stdout, space_around_delimiters=False)
