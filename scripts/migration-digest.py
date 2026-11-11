#!/usr/bin/env python3
"""Hash migration inputs, including linked personal configuration contents."""
import hashlib
import os
from pathlib import Path
import sys

root, step, dotfiles, clone_root = Path(sys.argv[1]), sys.argv[2], Path(sys.argv[3]), Path(sys.argv[4])
hash_value = hashlib.sha256()

def add(path, ancestors=frozenset()):
    hash_value.update(os.fsencode(str(path)) + b'\0')
    if path.is_symlink():
        hash_value.update(b'link\0' + os.fsencode(os.readlink(path)) + b'\0')
    if not path.exists():
        hash_value.update(b'missing\0')
    elif path.is_file():
        hash_value.update(b'file\0')
        with path.open('rb') as stream:
            for chunk in iter(lambda: stream.read(65536), b''):
                hash_value.update(chunk)
        hash_value.update(b'\0')
    elif path.is_dir():
        resolved = path.resolve()
        if resolved in ancestors:
            raise SystemExit(f'Configuration symlink cycle: {path}')
        hash_value.update(b'dir\0')
        for child in sorted(path.iterdir()):
            if child.name not in ('.git', '__pycache__'):
                add(child, ancestors | {resolved})

for name in (step, 'config', 'functions', 'migration', 'ssh-config-template',
             'wsl-template.conf', 'repository_locations.yml'):
    add(root / name)
for helper in sorted((root / 'scripts').iterdir()):
    if helper.suffix in ('.py', '.sh'):
        add(helper)

personal = {
    '02-add-symlinks': ['ghostty', 'gits', 'starship/starship.toml', 'yazi',
                        'bash/inputrc', 'bash/xinitrc', 'git/gitconfig',
                        'git/gitignore_global', 'latex/latexmkrc'],
    '05-replace-bashrc': ['bash'],
    '20-update-omarchy-hyprland': ['hypr'],
    '21-update-omarchy-shell': ['omarchy/shell.json'],
    '21-update-omarchy-waybar': ['waybar'],
}
for name in personal.get(step, []):
    add(dotfiles / name)
if step == '02-add-symlinks':
    for name in ('nvim.traap', 'tmux/tmux.conf', 'vim/vimrc', 'ssh/config.vim'):
        add(clone_root / name)
if step == '09-add-tmux-plugins':
    add(clone_root / 'tmux/tmux.conf')
print(hash_value.hexdigest())
