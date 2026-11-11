# Numbered migration script review

## Implementation status

The findings below record the original review. The subsequent fixes address
the confirmed defects across the numbered steps and migration runner:

- Required failures stop migrations; disabled steps create no completion marker.
- Shared code, templates, and relevant external configuration
  contents invalidate resume markers.
- Private temporary files, collision-free backups, idempotent links, and
  preserved checkouts replace destructive rerun behavior.
- SSH directory setup belongs to step 04; personal keys/config are preserved,
  missing public keys can be recovered, and incoming SSH is explicitly enabled
  with the user-approved `sshServerFlag=true`.
- Language tools use explicit mise runtimes; Python CLI applications use pipx;
  Lua rocks target Lua 5.1. Forced npm audit mutations were removed.
- WSL changes are isolated to the WSL step and merge existing settings.
- VPN setup uses the supported Arch package and the documented per-user flat
  config, retains the configured IP, and enables certificate checks.
- TeX uses `texlive-basic`; Redis setup preserves existing Redis or installs
  its repository provider Valkey with the corresponding enabled service.
- AD configuration checks DNS/time, discovers its interface, preserves NSS
  providers, validates candidate configuration, backs up replaced files, and
  propagates required failures.

Verification: 25 isolated Ruby/Minitest regression tests, all numbered-script syntax/skip
paths, the migration dry run, and `git diff --check`. The repaired tmux plugin step was also exercised with a real TPM checkout and
a local plugin in a temporary home. Other enabled migrations, package installers,
live desktop reloads, domain joins, and VPN connections were not exercised.

Remaining deployment prerequisites: AD and VPN require the appropriate network, credentials, trust,
and site-specific authentication policies; these cannot be integration-tested
without those environments. Snapshot deletion is intentionally not performed.
Remote installers still use their upstream URLs rather than pinned releases.

## Original review (before fixes)

Reviewed the numbered `NN-*` files on 2026-11-11 against `migration`, `functions`,
`config`, and the local templates. No migration or installer was run.
All reviewed scripts pass `bash -n` and execute successfully with their flag disabled.
Package names, remote installers, and current upstream compatibility have not
been verified; entries requesting those checks are follow-up work.

## Highest priority

1. **Failure reporting:** `log_fail` only prints and returns success. Several
   steps swallow command failures and are then marked complete by `migration`.
   Isolated mocks confirmed failed installs exit zero in `53-add-packages-pip`,
   `59-add-ruby`, and `60-add-rails`. Return nonzero explicitly for required work;
   distinguish optional warnings from a completed installation.
2. **SSH ordering:** `02-add-symlinks:54` can move an existing `.ssh` directory
   aside and link another one before `04` checks it. This can remove existing
   identities and known-host settings from active use. Give `04` sole ownership
   of SSH setup or add reconciliation before either step changes `.ssh`.
3. **Fixed temporary paths:** `50-add-mise:11` and `70-add-vpn:44` write predictable
   files in shared `/tmp`. Use private temporary files/directories and cleanup
   traps to prevent collisions and following preexisting symlinks.
4. **Unrelated npm mutations:** `52-add-packages-nodejs:29` runs
   `npm audit fix --force` in the bootstrap repository, without a project scope.
   Remove this operation; it does not validate the preceding global installs.

## Per-script findings

| Script | Potential update |
| --- | --- |
| `00-add-gits` | Clean up the downloaded installer on failure; guard/back up replacement of repository locations. PATH changes here do not survive into later migration subprocesses. |
| `00-add-packages-pacman` | Docker is installed even when `dockerPackagesFlag=false`; clarify ownership of this package. Document the expected system-update prerequisite. |
| `00-add-packages-yay` | Check bootstrap dependencies (`git`, `makepkg`, build tools) when the pacman step is disabled; clean up the build directory. |
| `01-clone-my-repos` | Check `gits` availability explicitly; reconcile its configured clone destinations with `cloneRoot` instead of assuming `-r git` selects the same root. |
| `02-add-symlinks` | Resolve SSH ownership above. Avoid second-resolution backup collisions; do not accept dangling source symlinks as usable sources. `config.vim` is linked before `04` creates it, so a fresh setup misses that link. |
| `03-add-openssh` | Split client installation from starting the SSH server: `openSSLFlag` currently enables both. Verify service availability for platforms without systemd. |
| `04-add-ssh-keys` | Recent fix reviewed. Still validate the configured name for SSH-config whitespace, newlines, and metacharacters; filename validation alone is insufficient. Recover a missing public key from its private key; reject broken key/config symlinks. Coordinate with `02`. Key generation remains interactive. |
| `05-replace-bashrc` | Back up existing files before truncating them (including symlink targets). Render the configured `dotfiles` path instead of hardcoding `~/git/dotfiles`; guard interactive-only `bind`. |
| `07-add-nvims` | Add cleanup on installer failure and verify the installed command is reachable in subsequent steps. |
| `08-update-archlinux-mirrors` | Preserve the previous mirrorlist and validate a nonempty generated list before replacement. Repeated keyring initialization is unrelated to selecting mirrors. |
| `09-add-bash-git-prompt` | Replace unconditional `rm -rf` with an existing-checkout policy that preserves local changes; clone to a temporary destination before replacing anything. |
| `09-add-starship-prompt` | Clean up on failure; define an intentional interactive/noninteractive installer policy. |
| `09-add-tmux-plugins` | Skip or safely update an existing TPM checkout; reruns currently fail at `git clone`. Invoke the installer from the configured destination and verify tmux configuration/session prerequisites. |
| `10-update-ca-certificated` | No clear control-flow defect found. Clarify that this refreshes system trust and does not import any enterprise certificate itself; filename typo is cosmetic. |
| `11-generate-utf-8` | Gate WSL changes on WSL detection or move them into `85`. The sed range begins and ends on the same `[interop]` header and inserts another setting on reruns instead of normalizing the section. Preserve other locale settings. |
| `20-update-omarchy-hyprland` | Validate installed entry-point/module compatibility before linking. Guard reload on a running session, preserve replaced symlinks, and make already-correct links a no-op. Validate reported config errors explicitly. |
| `21-update-omarchy-shell` | Good existing-link guard. Validate JSON before activation and ensure backup destinations cannot collide; installed-shell schema compatibility remains unverified. |
| `21-update-omarchy-waybar` | Create the parent config directory for standalone use; skip an already-correct link rather than making another backup on each run. |
| `50-add-mise` | Use a private temporary installer and cleanup. Ensure later subprocesses can locate mise and its managed tools; exports in another step cannot establish that. |
| `52-add-packages-nodejs` | Use an explicit global or intended project scope for `mise use`; execute npm through the selected runtime. Avoid root-owned files in a user-managed runtime, remove forced audit mutation, and propagate install failures. |
| `53-add-packages-pip` | Missing Python and failed package installs currently report success. Choose an isolated app environment such as a venv rather than modifying system Python; verify the target interpreter's packaging policy before installing. |
| `54-add-packages-luarocks` | Missing LuaRocks and failed rock installs report success. Verify `neovim-remote` belongs in this package list (it is also listed in the pip step), and choose the Lua version required by the consuming application. |
| `55-add-packages-tex` | Verify all TeX package names against the target repositories before enabling; use the appropriate package manager and check dependencies when yay installation is disabled. |
| `57-add-packages-docker` | Use a nonpaging status command or `is-active` for automation. Clarify Docker package ownership with `00`; explicitly describe the intended user access policy. |
| `59-add-ruby` | A failed `mise use` is followed by successful `hash -r`, masking failure; missing mise also returns success after logging. Use explicit errors and verify the selected Ruby is executable. |
| `60-add-rails` | Missing gem and failed installation can report success. Execute through the selected mise Ruby and make required installation/version checks fail the step. |
| `61-add-brave-browser` | Missing curl reports success. Add cleanup on failure and verify the installer result/command before recording completion. |
| `62-remove-omarchy-chromium` | Detect installed packages with `pacman -Q`, not the presence of a same-named executable. Define an intentional prompt policy and verify the target package before removal. |
| `63-remove-omarchy-nvim` | Same package-versus-command detection problem as `62`; verify actual package ownership before choosing the removal target. |
| `70-add-vpn` | Replace fixed `/tmp/config.toml`, preserve existing config, and validate values before TOML rendering. Server certificate verification is explicitly disabled; replace that workaround with a verified hostname/trust configuration. Verify package/build dependencies against the target system. |
| `81-remove-orphaned-packages` | Distinguish an empty query from a failed package query instead of suppressing every error. Document that all current orphan packages are candidates, including ones unrelated to this migration. |
| `82-msql-support` | Align package-install prompt behavior with the rest of the runner. Correct the copied ThinkPad header; check that the intended SQL client functionality is actually covered. |
| `83-add-microsoft-programs` | Explicit yay prerequisite is useful; no clear additional control-flow defect found. Verify package availability before enabling. |
| `84-add-redis` | Use `enable --now` if startup after reboot is intended; current code only starts the service. Verify package/service names for the target repositories. |
| `85-add-wsl` | Detect WSL before writing `/etc/wsl.conf`; merge existing sections instead of overwriting the entire file. Escape/validate replacement values and coordinate interop settings with `11`. |
| `97-thinkpad-support` | Match kernel headers to the running kernel rather than always installing `linux-headers`. Under pipefail, `yes` can receive SIGPIPE and turn successful sensor detection into a warning. Separate mandatory failures from optional hardware checks; avoid claiming success for failed required services. |
| `98-ad-integration` | Discover the interface instead of hardcoding `eth0`; add NSS `sss` integration here rather than depending on a separate repair flag. Preserve Kerberos/Samba/SSSD configs, validate them before restarting services, and return failure for required join/configuration failures. Reachability of one DNS server via ping is not sufficient domain detection. |
| `98-ad-rejoin-fix` | Handle failed `ip route get` so errexit does not bypass the fallback. Preserve existing NSS providers instead of replacing entire lines. This pre-join fix sorts after the join step; either run it before joining or make integration self-contained. DNS/service errors currently lead to success messages. |
| `99-diable-omarchy-snapshots` | Check installed units/commands and make absent components an intentional no-op. Clarify the flag description: the script disables timers/services but does not delete snapshots. Verify why synchronization is invoked immediately after disabling its service. |

## Runner issues affecting the scripts

- Completion hashes omit `functions`, templates, and
  external dotfiles; changing them does not invalidate `--resume` markers.
- A disabled step is also marked complete. Environment changes and newly
  available dependencies do not invalidate that marker.
- `--dry-run` lists all steps, although its help promises enabled steps.
- `--step` accepts any existing top-level file, not just numbered migrations.
- `bash -n functions config migration` checks only the first script argument;
  validate these files individually as is already done for numbered steps.
- Each step runs in a separate Bash process. Establish tool paths and runtime
  selection per step or in a shared initialization layer, not by exports in
  an earlier step.

## Verification limits

The failure-path checks used shell functions as command mocks and did not
install packages, create keys, alter the desktop, or contact remote services.
The disabled-flag checks verify the skip path only. Enabled paths and current
package/upstream behavior require targeted checks before applying fixes.
