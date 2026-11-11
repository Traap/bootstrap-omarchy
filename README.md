## Omarchy Customizing
**DO NOT USE THESE SCRIPTS WITHOUT READING THEM FIRST.**
**YOU HAVE BEEN WARNED!**

Traap

## TL;DR

Clone **bootstrap-omarchy**, edit `config`, run the migration.

```bash
git clone https://github.com/Traap/bootstrap-omarchy
cd bootstrap-omarchy
./migration
```

Validate and preview the ordered steps before applying them:

```bash
./migration --dry-run
./migration --step 20-update-omarchy-hyprland
./migration --resume
```

`--resume` records enabled steps only after success. Its hash includes the
step, `config`, shared helpers, templates, and relevant
personal configuration files. Editing these inputs makes the step eligible to
run again. Changes to the installed system or remote installers are not tracked;
rerun the step without `--resume` to reapply it.

Answering `N` to the Starship installation prompt skips that step and continues
the migration. Declined steps do not receive completion markers and are offered
again on later runs. Step exit code 77 is reserved for an intentional skip.

Steps run in separate Bash processes with strict error handling. Python 3 is
required by the runner; common user-tool paths are initialized for every step.
Existing configuration is backed up beside its original path in a unique
`*.bak.XXXXXXXX/original` location before replacement. Existing checkouts are
preserved rather than reset or deleted.

`sshServerFlag=true` enables incoming SSH connections when the OpenSSH step is
enabled. The SSH key step refuses to replace an unrelated existing `~/.ssh`
directory; reconcile that directory with `$cloneRoot/ssh` before running it.
New personal keys prompt for a passphrase.

The tmux steps create `~/.config/tmux -> $cloneRoot/tmux` (or use
`$XDG_CONFIG_HOME/tmux`), backing up an existing config directory. Matching
legacy `~/.tmux` and `~/.tmux.conf` symlinks are removed; unrelated paths are
preserved. Plugin installation initializes TPM in a
temporary tmux server and leaves existing sessions untouched.

Python CLI applications use pipx, and Ruby/Node commands run through explicit
mise runtimes. WSL configuration is changed only by the WSL step. Snapshot
setup disables automatic units and preserves existing snapshots.

VPN setup uses the upstream-supported [Arch package](https://github.com/ancwrd1/snx-rs/blob/main/docs/installation.md)
and [per-user command-mode configuration](https://github.com/ancwrd1/snx-rs/blob/main/docs/quick-start.md).
It retains the configured server IP and enables certificate checks. A trusted
certificate must identify that IP or the configured hostname. No VPN connection
is started by the installer.

AD steps require domain DNS, synchronized time, credentials, and
site-appropriate PAM authentication policy.

Run the isolated Ruby regression checks with Minitest (install once if needed):

```bash
gem install minitest -v '~> 5.0'
ruby tests/test_migrations.rb
```

See [SCRIPT-REVIEW.md](SCRIPT-REVIEW.md) for the original audit and fix status.

Open `config` and toggle `false` → `true` for the applications you want
installed or removed.

## An Attempt at Humor

Good news: **Omarchy, DHH, and Traap are all opinionated.** Even better news:
**everyone wins.**

Truth be told, if I agreed 100% with everyone on everything 100% of the time,
I’d basically be talking to myself… which I already do — and yes, I answer
myself too.

It’s *my* computer, so *my* opinion wins. If I break an elegant Omarchy setup
crafted by an amazing team, well, that’s my problem and mine to fix.

## On a Serious Note

I’ve been living inside tiling window managers (BSPWM, Hyprland), terminals
(alacritty, ghostty, kitty, MS Terminal), shells (bash and Git Bash), and TMUX
for years.

I routinely study:

- keyboard layout differences
- window movement and ergonomics
- key sequences and physical efficiency

Whenever I hit an awkward or inefficient action, I:
1. document it,
2. analyze it,
3. fix it.

I move seamlessly between:

- BSPWM and Hyprland
- Vim and Neovim
- Arch Linux, Ubuntu
- WSL2 running Arch or Ubuntu
- Git Bash on Windows

Linux-based systems are consistently flawless; Windows requires a little
“creative persuasion.” Omarchy gives me the perfect foundation. My scripts add
workflow polish.

## The Solution

Omarchy is built upon **the greatest Linux distribution ever**: Arch Linux.

I began with strict Omarchy defaults, studied their scripts (they truly *are*
excellent), then added minimal workflow refinements. After installing Omarchy on
multiple laptops and validating I could maintain a consistent workflow
everywhere, I layered my personal customizations on top.

## The Journey Begins with `.bashrc` and `.inputrc`

My bash environment merges Omarchy defaults with my personal configuration:

```bash
## All the default Omarchy aliases and functions
source ~/.local/share/omarchy/default/bash/rc

## Traap’s customizations
source ~/git/dotfiles/bash/bashrc

## Don't mess with my .inputrc
bind -f ~/.inputrc
```

## My Personalized Bash Login Process

I document everything I care about. I’ve been “bashing” since 2014 — almost
thirteen years of muscle memory and visual habits.

Here are the files that define my login experience:
- [bash_profile](https://github.com/Traap/dotfiles/blob/master/bash/bash_profile)
- [bashrc](https://github.com/Traap/dotfiles/blob/master/bash/bashrc)
- [bashrc_personal](https://github.com/Traap/dotfiles/blob/master/bash/bashrc_personal)
- [inputrc](https://github.com/Traap/dotfiles/blob/master/bash/inputrc)

These files are non-negotiable. They’re my superpowers.

## Configuration Philosophy

1. **YAGNI** — add nothing unless truly needed.
2. **Drop-in, drop-out** — everything reversible.
3. **Single source of truth (`config`)**.
4. **Reproducibility first**.
5. **Respect Omarchy defaults**.
6. **Document everything**.
7. **Cross-environment consistency**.
8. **Escape hatches everywhere**.
9. **Never fight upstream**.
10. **Zero bloat**.

## Design Principles

- Minimal surprises
- Fail loud, fail fast
- Composable, not entangled
- Idempotent behavior
- Human-readable first
- Local overrides are sacred
- Environment agnostic
- Escape hatches everywhere
- Respect upstream
- Zero bloat

## System Diagram

```ascii
                       ┌────────────────────────────────┐
                       │         Omarchy Base           │
                       │  (Arch Linux + Omarchy setup)  │
                       └────────────────────────────────┘
                                      │
                                      ▼
                     ┌───────────────────────────────────┐
                     │        bootstrap-omarchy          │
                     │     (Your customization layer)    │
                     └───────────────────────────────────┘
                                      │
                                      ▼
                     ┌───────────────────────────────────┐
                     │               config              │
                     │  Single source of truth: flags    │
                     │  define WHAT the system becomes   │
                     └───────────────────────────────────┘
                                      │
                                      ▼
                     ┌───────────────────────────────────┐
                     │              migration            │
                     │  Executes steps based on flags    │
                     │  • Check flag                     │
                     │  • Run script                     │
                     │  • Fail fast                      │
                     │  • Stay reversible                │
                     └───────────────────────────────────┘
                                      │
                                      ▼
              ┌────────────────────────────────────────────────────────┐
              │                       Steps                            │
              │       (Only those enabled in config are run)           │
              │                                                        │
              │  - pacman packages        - tmux plugins               │
              │  - yay packages           - Neovim configs             │
              │  - Hyprland setup         - BSPWM setup                │
              │  - nodejs / ruby / go     - ssh keys / starship        │
              │  - TeX Live               - certificates / OpenSSL     │
              │  - clone repositories     - ThinkPad support           │
              │  - Kerberos configs       - locale generation          │
              └────────────────────────────────────────────────────────┘
                                      │
                                      ▼
                     ┌───────────────────────────────────┐
                     │         Customized System         │
                     │   (Laptop, workstation, WSL2 —    │
                     │    all consistent & reproducible) │
                     └───────────────────────────────────┘
```

## The Migration

Omarchy uses a Rails-inspired migration system:

1. `config` — defines what to install or remove
2. `migration` — executes each step in sequence

Different machines require different tools. `config` declares their identity.

### Omarchy Quattro

Quattro uses Lua-based Hyprland configuration and Omarchy Shell (Quickshell).
The Hyprland step therefore preserves `~/.config/hypr/hyprland.lua` and links
only personal override modules. The shell step links
`$dotfiles/omarchy/shell.json`; Waybar remains a separately enabled legacy
option.

Full [config](https://github.com/Traap/bootstrap-omarchy/blob/master/config)
