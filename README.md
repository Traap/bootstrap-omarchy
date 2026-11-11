## Omarchy Customizing
**DO NOT USE THESE SCRIPTS WITHOUT READING THEM FIRST.**
**YOU HAVE BEEN WARNED!**

Traap

## TL;DR

On an already-installed **Omarchy 4.5+** system, clone **bootstrap-omarchy**,
edit `config`, and run the personal customizations. All 36 flags default to
false; this repository does not reinstall the base desktop.

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

Step exit code 77 means an intentional skip, such as a disconnected dock.
Skipped steps do not receive completion markers and can be retried later.

Steps run in separate Bash processes with strict error handling. Python 3 is
required by the runner; common user-tool paths are initialized for every step.
Existing configuration is backed up beside its original path in a unique
`*.bak.XXXXXXXX/original` location before replacement. Existing checkouts are
preserved rather than reset or deleted.

`sshClientFlag` installs OpenSSH client tools. `sshServerFlag` independently
installs, validates, and enables incoming SSH connections; it defaults to false.
`sshIdentityFlag` creates/preserves the personal identity named `sshKeyName`.
The SSH key step refuses to replace an unrelated existing `~/.ssh` directory; reconcile that directory with `$cloneRoot/ssh` before running it.
New personal keys prompt for a passphrase.

The tmux steps create `~/.config/tmux -> $cloneRoot/tmux` (or use
`$XDG_CONFIG_HOME/tmux`), backing up an existing config directory. Matching
legacy `~/.tmux` and `~/.tmux.conf` symlinks are removed; unrelated paths are
preserved. Plugin installation initializes TPM in a temporary tmux server and leaves existing sessions untouched.

Python CLI applications use pipx. `rubyVersion` is an explicit application
runtime choice; `nodeVersion` can be blank to retain the inherited Omarchy/mise
selection. Additional npm packages exclude Omarchy-managed agent CLIs. The
repository no longer contains a Node/npm mise.toml that overrides that selection.

Brave and Visual Studio Code use native Omarchy installers. The repository
package overlay contains personal additions; legacy X11 tools have their own
`x11ToolsFlag`. Packaged mise, Starship, yay, locale/trust maintenance, and orphan
cleanup remain with the distribution.

`dockerServiceFlag` applies `dockerServiceMode=socket|daemon` to existing Docker.
Socket mode preserves running containers and changes future startup policy;
the script does not change docker-group membership.

`thinkpadSupportFlag` configures sensors/dock NIC modules on detected ThinkPads.
`displayLinkFlag` independently installs EVDI for an attached dock.
`thinkpadTlpFlag` explicitly replaces the installed power-profiles provider with
TLP and attempts to restore that provider if installation or service checks fail.
A recovery failure is reported; hardware/package transitions still require
verification on the target machine. Ordinary hardware support leaves power
management alone.

Snapshot creation and boot synchronization remain managed by Omarchy. The old
snapshot-disabling step was replaced with `snapshotRetentionFlag`, which uses
Snapper's native configuration command to set `snapshotNumberLimit`,
`snapshotImportantLimit`, and `snapshotMinAge`. The count defaults are 5 normal
and 5 important snapshots, starting from the current Omarchy template. They are
independent limits, not a combined cap. A minimum age can keep younger snapshots
beyond those limits. Lowering limits affects subsequent automatic cleanup; this
step backs up the config and does not create, delete, or clean snapshots itself.

Set `targetProfile=legacy-waybar` or `targetProfile=wsl` before opting into those
separate platform steps; neither profile enables flags automatically.

VPN setup uses the upstream-supported [Arch package](https://github.com/ancwrd1/snx-rs/blob/main/docs/installation.md)
and [per-user command-mode configuration](https://github.com/ancwrd1/snx-rs/blob/main/docs/quick-start.md).
It retains the configured server IP and enables certificate checks. A trusted
certificate must identify that IP or the configured hostname. No VPN connection
is started by the installer.

AD steps require domain DNS, synchronized time, credentials, and
site-appropriate PAM authentication policy.

Run the isolated Ruby regression checks with Minitest (install once if needed):

```bash
gem install minitest
ruby tests/test_migrations.rb
```

See [SCRIPT-REVIEW.md](SCRIPT-REVIEW.md) for the original audit and fix status.
See [Upgrading an existing config](#upgrading-an-existing-config) for renamed
and retired settings. Start with the new config and migrate intentional
customizations rather than copying old flags wholesale.

Open `config` and toggle `false` → `true` for the applications you want
installed or removed.

## Upgrading an existing config

All 36 flags default to false. Renamed settings below have compatibility aliases
that work in both the runner and its step subprocesses. Conflicting old/new
values fail validation before any step is applied.

| Previous setting | Current setting |
| --- | --- |
| `adRejoinFlag` | `adRepairFlag` |
| `hyprlandFlag` | `hyprlandOverridesFlag` |
| `nvimsFlag` | `nvimSwitcherFlag` |
| `microsoftFlag` | `vscodeFlag` |
| `luarocksFlag` | `luaRocksPackagesFlag` |
| `nodeJsFlag` | `nodePackagesFlag` |
| `openSSLFlag` | `sshClientFlag` |
| `sshHostKeyFlag` | `sshIdentityFlag` |
| `pipPackagesFlag` | `pythonCliPackagesFlag` |
| `dockerPackagesFlag` | `dockerServiceFlag` (old enabled configs retain daemon mode unless explicitly configured) |
| `thinkpadFlag` | `thinkpadSupportFlag` (sensors/dock NIC modules only; TLP and DisplayLink are separate opt-ins) |
| `archHostName` | `sshKeyName` and `wslHostName` |
| `archUserName` | `wslUserName` |

`sshServerFlag` is now independent and defaults to false. The old combination
`openSSLFlag=false` with `sshServerFlag=true` is rejected until you remove the
old setting and explicitly choose the server policy. This prevents an old,
formerly inert default from enabling incoming connections.

Enabled retired flags are errors; old false values are tolerated during an
incremental upgrade. Remove `miseFlag`, `starshipFlag`, `certificatesFlag`,
`utf8Flag`, `orphanedFlag`, `omarchyChromiumBrowserFlag`, `yayPackagesFlag`, and
`snapshotFlag`. Their redundant or legacy steps are removed. Extra repository
packages now belong to `pacmanPackagesFlag`, with explicit AUR app installers
using the provided package manager. Use `omarchy update orphan-pkgs` for orphan
maintenance. Personal Starship settings remain in dotfiles.

The snapshot replacement, `snapshotRetentionFlag`, changes retention only. If
the old disabling step was already applied, restore Omarchy's snapshot services
separately; the retention step does not change units. No cleanup/deletion is
invoked when configuring retention.

The Node/npm project `mise.toml` was removed to preserve inherited runtime
selection. Unused `gitEmail`, `LOG_FILE`, `VPN_INTERFACE`, and `timezone` settings
were also removed. No current step sets the native machine hostname.

For `--step`, use `57-configure-docker-service`, `83-add-vscode`, and
`98-ad-repair` instead of their previous `57-add-packages-docker`,
`83-add-microsoft-programs`, and `98-ad-rejoin-fix` names. New independent steps
include `03-enable-ssh-server`, `00-add-packages-x11`, `97-displaylink-support`,
`97-thinkpad-tlp`, and `99-configure-snapshot-retention`.

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
              │  - personal packages       - tmux plugins              │
              │  - legacy X11 tools        - Neovim switching          │
              │  - Hyprland overrides      - shell overrides           │
              │  - Node/Ruby app tools     - SSH identities            │
              │  - TeX collections         - SSH client/server         │
              │  - personal repositories   - ThinkPad/DisplayLink      │
              │  - AD/VPN integration      - optional app tools        │
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
