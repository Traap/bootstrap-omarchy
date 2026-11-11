# frozen_string_literal: true

# Regression tests use temporary homes and command mocks, never host mutation.
require 'fileutils'
gem 'minitest', '~> 5.0'
require 'minitest/autorun'
require 'open3'
require 'pathname'
require 'tmpdir'

class MigrationTests < Minitest::Test
  ROOT = Pathname.new(__dir__).parent.realpath
  STEPS = ROOT.children.select { |path| path.file? && path.basename.to_s.match?(/^\d{2}-/) }.sort.freeze
  Result = Struct.new(:stdout, :stderr, :status) do
    def exitstatus = status.exitstatus
  end

  def setup
    @temp = Pathname.new(Dir.mktmpdir('migration-tests-'))
    @home = @temp / 'home'
    @home.mkdir
    @env = {
      'HOME' => @home.to_s,
      'XDG_STATE_HOME' => (@home / 'state').to_s,
      'BASH_ENV' => nil,
      'XDG_CONFIG_HOME' => nil
    }
  end

  def teardown
    FileUtils.remove_entry(@temp) if @temp&.exist?
  end

  def capture(*command, input: '', cwd: ROOT)
    Result.new(*Open3.capture3(@env, *command.map(&:to_s), stdin_data: input, chdir: cwd.to_s))
  end

  def bash(code, cwd: ROOT, input: '')
    capture('bash', '-euo', 'pipefail', '-c', code, cwd: cwd, input: input)
  end

  def step(name, setup, input: '')
    bash("source ./functions\nMIGRATION_ROOT=\"$PWD\"\n#{setup}\nsource \"./#{name}\"", input: input)
  end

  def assert_success(result, context = '')
    assert_equal 0, result.exitstatus, "#{context}\n#{result.stdout}\n#{result.stderr}"
  end

  def test_syntax_and_disabled_flags
    [*STEPS, ROOT / 'migration', ROOT / 'config', ROOT / 'functions', ROOT / 'scripts/ad-access.sh'].each do |path|
      assert_success capture('bash', '-n', path), path.basename.to_s
    end
    STEPS.each do |path|
      flags = path.read.scan(/\$\{?(\w+Flag)/).flatten.uniq
      assert_success step(path.basename.to_s, flags.map { |flag| "#{flag}=false" }.join("\n")), path.basename.to_s
    end
  end

  def test_required_install_failures_propagate
    cases = {
      '52-add-packages-nodejs' => 'nodeJsFlag=true; mise() { return 42; }',
      '53-add-packages-pip' => 'pipPackagesFlag=true; sudo() { :; }; pipx() { return 42; }',
      '54-add-packages-luarocks' => 'luarocksFlag=true; sudo() { if [[ $1 == pacman ]]; then return 0; fi; "$@"; }; luarocks() { return 42; }',
      '59-add-ruby' => 'rubyFlag=true; rubyVersion=ruby@4; mise() { return 42; }',
      '60-add-rails' => 'railsFlag=true; rubyVersion=ruby@4; sudo() { :; }; mise() { return 42; }',
      '70-add-vpn' => 'vpnFlag=true; yay() { return 42; }; sudo() { :; }'
    }
    cases.each { |name, setup| refute_equal 0, step(name, setup).exitstatus, name }
  end

  def test_ssh_creation_rerun_recovery_and_protection
    # Force empty passphrases for temporary test keys only.
    setup = <<~'BASH'
      sshHostKeyFlag=true
      cloneRoot="$HOME/custom git"
      archHostName=TestHost
      gitUserName=Tester
      ssh-keygen() { command ssh-keygen "$@" -N ''; }
    BASH
    assert_success step('04-add-ssh-keys', setup)
    ssh = @home / 'custom git/ssh'
    assert_equal ssh, (@home / '.ssh').realpath
    assert_equal 0o600, (ssh / 'TestHost').stat.mode & 0o777
    assert_equal 0o700, ssh.stat.mode & 0o777
    config = (ssh / 'config').read
    assert_includes config, 'User git'
    assert_includes config, 'IdentityFile ~/.ssh/TestHost'
    assert_equal ssh / 'config.vim', (@home / '.config.vim').realpath
    private_key = (ssh / 'TestHost').binread
    (ssh / 'config').write("custom settings\n")
    (ssh / 'TestHost.pub').unlink
    # -y does not accept -N; use the actual command for recovery.
    assert_success step('04-add-ssh-keys', setup.sub(%q(ssh-keygen() { command ssh-keygen "$@" -N ''; }), ''))
    assert_equal private_key, (ssh / 'TestHost').binread
    assert (ssh / 'TestHost.pub').read.start_with?('ssh-ed25519 ')
    assert_equal "custom settings\n", (ssh / 'config').read
    (@home / '.ssh').unlink
    (@home / '.ssh').mkdir
    (@home / '.ssh/known_hosts').write('preserve')
    refute_equal 0, step('04-add-ssh-keys', setup).exitstatus
    assert_equal 'preserve', (@home / '.ssh/known_hosts').read
    refute_equal 0, step('04-add-ssh-keys', setup.sub('archHostName=TestHost', "archHostName='bad host'")).exitstatus
  end

  def test_ssh_correct_dangling_directory_link
    (@home / '.ssh').make_symlink(@home / 'git/ssh')
    assert_success step('04-add-ssh-keys', <<~'BASH')
      sshHostKeyFlag=true
      cloneRoot="$HOME/git"; archHostName=TestHost; gitUserName=Tester
      ssh-keygen() { command ssh-keygen "$@" -N ''; }
    BASH
  end

  def test_ssh_server_setting_controls_service_startup
    setup = <<~'BASH'
      openSSLFlag=true
      sudo() { printf '%s\n' "$*" >> "$HOME/commands"; }
      ssh() { :; }; openssl() { :; }
    BASH
    assert_success step('03-add-openssh', setup + 'sshServerFlag=true')
    assert_includes (@home / 'commands').read, 'systemctl enable --now sshd.service'
    (@home / 'commands').unlink
    assert_success step('03-add-openssh', setup + 'sshServerFlag=false')
    refute_includes (@home / 'commands').read, 'systemctl'
  end

  def test_bashrc_rendering_preserves_symlink_target_and_reruns
    original = @home / 'original'
    original.write("# original settings\n")
    (@home / '.bashrc').make_symlink(original)
    setup = 'bashrcFlag=true; dotfiles="$HOME/dot files"; OMARCHY_PATH="$HOME/omarchy"'
    assert_success step('05-replace-bashrc', setup)
    assert_equal "# original settings\n", original.read
    refute (@home / '.bashrc').symlink?
    assert_includes (@home / '.bashrc').read, 'dot\ files/bash/bashrc'
    assert_success bash('source "$HOME/.bashrc"')
    backups = @home.glob('.bashrc.bak.*')
    assert_equal 1, backups.length
    assert_success step('05-replace-bashrc', setup)
    assert_equal backups, @home.glob('.bashrc.bak.*')
  end

  def test_missing_snapshot_units_are_skipped
    assert_success step('99-diable-omarchy-snapshots', <<~'BASH')
      snapshotFlag=true
      systemctl() { printf '%s\n' not-found; }
      sudo() { return 42; }
    BASH
  end

  def test_wsl_guard_prevents_system_changes
    result = step('85-add-wsl', 'wslFlag=true; is_wsl() { return 1; }; sudo() { touch "$HOME/unexpected"; }')
    refute_equal 0, result.exitstatus
    refute (@home / 'unexpected').exist?
  end

  def test_link_reruns_and_unique_backups
    (@home / 'source').write('source')
    target = @home / 'target'
    target.write('original')
    assert_success bash('source ./functions; safe_link "$HOME/source" "$HOME/target"; safe_link "$HOME/source" "$HOME/target"')
    backups = @home.glob('target.bak.*/original')
    assert_equal 1, backups.length
    assert_equal 'original', backups.first.read
    target.unlink
    target.write('second')
    assert_success bash('source ./functions; safe_link "$HOME/source" "$HOME/target"')
    assert_equal 2, @home.glob('target.bak.*/original').length
  end

  def test_symlinks_step_preserves_ssh_directory
    (@home / '.ssh').mkdir
    (@home / '.ssh/key').write('original')
    (@home / 'git/ssh').mkpath
    assert_success step('02-add-symlinks', 'symlinksFlag=true; cloneRoot="$HOME/git"; dotfiles="$HOME/dotfiles"')
    refute (@home / '.ssh').symlink?
    assert_equal 'original', (@home / '.ssh/key').read
  end

  def test_tmux_directory_link_replaces_legacy_links_and_preserves_configuration
    source = @home / 'git/tmux'
    source.mkpath
    (source / 'tmux.conf').write('# personal config')
    (@home / '.tmux').make_symlink(source)
    (@home / '.tmux.conf').make_symlink(source / 'tmux.conf')
    setup = 'symlinksFlag=true; cloneRoot="$HOME/git"; dotfiles="$HOME/dotfiles"'
    assert_success step('02-add-symlinks', setup)
    assert_equal source, (@home / '.config/tmux').realpath
    assert (@home / '.config/tmux').symlink?
    refute (@home / '.tmux').symlink?
    refute (@home / '.tmux.conf').symlink?
    assert_equal '# personal config', (source / 'tmux.conf').read
    assert_success step('02-add-symlinks', setup)
    assert_empty @home.glob('.config/tmux.bak.*')
  end

  def test_tmux_link_cleanup_preserves_unrelated_legacy_paths_and_honors_xdg
    source = @home / 'git/tmux'
    source.mkpath
    (source / 'tmux.conf').write('# personal config')
    (@home / '.tmux').mkdir
    (@home / '.tmux/keep').write('keep')
    (@home / '.tmux.conf').make_symlink(@home / 'unrelated.conf')
    @env['XDG_CONFIG_HOME'] = (@home / 'custom-config').to_s
    assert_success bash('source ./functions; configure_tmux_links "$HOME/git/tmux"')
    assert_equal source, (@home / 'custom-config/tmux').realpath
    assert_equal 'keep', (@home / '.tmux/keep').read
    assert_equal @home / 'unrelated.conf', (@home / '.tmux.conf').readlink
  end

  def tpm_setup(installer_status: 0)
    bin = @home / 'bin'
    bin.mkdir
    (bin / 'tmux').write(<<~'BASH')
      #!/usr/bin/env bash
      printf '%s\n' "$*" >> "$HOME/tmux-commands"
    BASH
    (bin / 'tmux').chmod(0o755)
    checkout = @home / 'git/tmux/plugins/tpm'
    (checkout / '.git').mkpath
    (checkout / 'bin').mkpath
    (@home / 'git/tmux/tmux.conf').write("set -g @plugin 'example/plugin'\n")
    (checkout / 'bin/install_plugins').write(<<~BASH)
      #!/usr/bin/env bash
      tmux show-environment -g TMUX_PLUGIN_MANAGER_PATH
      exit #{installer_status}
    BASH
    (checkout / 'bin/install_plugins').chmod(0o755)
    <<~'BASH'
      tmuxPluginsFlag=true
      cloneRoot="$HOME/git"
      export PATH="$HOME/bin:$PATH"
      git() { [[ $* == *'remote get-url origin' ]] && printf '%s\n' https://github.com/tmux-plugins/tpm.git; }
    BASH
  end

  def test_tpm_existing_checkout_is_preserved
    setup = tpm_setup
    xdg = @home / '.config/tmux'
    xdg.mkpath
    (xdg / 'tmux.conf').write('# existing Omarchy configuration')
    assert_success step('09-add-tmux-plugins', setup)
    assert xdg.symlink?
    assert_equal @home / 'git/tmux', xdg.realpath
    assert_equal @home / 'git/tmux/tmux.conf', (xdg / 'tmux.conf').realpath
    assert_equal @home / 'git/tmux/plugins', (xdg / 'plugins').realpath
    assert_equal '# existing Omarchy configuration', @home.glob('.config/tmux.bak.*/original/tmux.conf').first.read
    assert_success step('09-add-tmux-plugins', setup)
    assert_equal 1, @home.glob('.config/tmux.bak.*').length
    commands = (@home / 'tmux-commands').read
    assert_includes commands, "set-environment -g TMUX_PLUGIN_MANAGER_PATH #{@home}/git/tmux/plugins/"
    assert_match(/-S (\S+) show-environment -g TMUX_PLUGIN_MANAGER_PATH/, commands)
    socket = commands.match(/-S (\S+) show-environment/)[1]
    refute Pathname.new(socket).parent.exist?, 'temporary server directory must be cleaned up'
    assert_includes commands, "-S #{socket} kill-server"
  end

  def test_tpm_failure_propagates_and_cleans_up_server
    result = step('09-add-tmux-plugins', tpm_setup(installer_status: 42))
    assert_equal 42, result.exitstatus
    commands = (@home / 'tmux-commands').read
    socket = commands.match(/-S (\S+) show-environment/)[1]
    assert_includes commands, "-S #{socket} kill-server"
    refute Pathname.new(socket).parent.exist?
    refute_includes result.stdout, 'TMUX plugins installed;'
  end

  def test_starship_decline_skips_without_running_installer
    setup = 'starshipFlag=true; run_installer() { touch "$HOME/installer-ran"; }'
    ["N\n", "n\n", "\n", ''].each do |answer|
      result = step('09-add-starship-prompt', setup, input: answer)
      assert_equal 77, result.exitstatus
      assert_includes result.stdout, 'Starship installation declined; continuing migration.'
      refute (@home / 'installer-ran').exist?
    end
  end

  def test_starship_acceptance_runs_installer_and_preserves_failures
    setup = <<~'BASH'
      starshipFlag=true
      run_installer() { printf '%s\n' "$*" > "$HOME/installer-args"; return 42; }
    BASH
    result = step('09-add-starship-prompt', setup, input: "Y\n")
    assert_equal 42, result.exitstatus
    assert_equal "https://starship.rs/install.sh sh --yes\n", (@home / 'installer-args').read
  end

  def test_installer_cleanup_after_failure
    downloads = @home / 'downloads'
    downloads.mkdir
    @env['TMPDIR'] = downloads.to_s
    result = bash(<<~'BASH')
      source ./functions
      curl() { while [[ $# -gt 0 ]]; do if [[ $1 == -o ]]; then shift; printf 'exit 37\n' > "$1"; fi; shift; done; }
      run_installer https://example.invalid/install.sh bash
    BASH
    assert_equal 37, result.exitstatus
    assert_empty downloads.children
  end

  def test_wsl_ini_merge_preserves_other_sections_and_is_idempotent
    original = "[interop]\nappendWindowsPath=true\nappendWindowsPath=true\n[user]\ndefault=old\n[custom]\nvalue=keep\n"
    command = ['python3', ROOT / 'scripts/merge-ini.py', 'interop', 'appendWindowsPath', 'false', 'user', 'default', 'new']
    result = capture(*command, input: original)
    assert_success result
    again = capture(*command, input: result.stdout)
    assert_success again
    assert_equal result.stdout, again.stdout
    assert_includes result.stdout, "[custom]\nvalue=keep\n"
    assert_includes result.stdout, "[interop]\nappendWindowsPath=false\n"
  end

  def test_nss_preserves_providers_and_actions
    original = "passwd: files systemd winbind [SUCCESS=return] # comment\ngroup: files sss\nhosts: files dns\n"
    command = ['python3', ROOT / 'scripts/update-nss.py']
    result = capture(*command, input: original)
    assert_success result
    assert_includes result.stdout, 'winbind [SUCCESS=return] sss # comment'
    assert_includes result.stdout, 'hosts: files dns'
    again = capture(*command, input: result.stdout)
    assert_success again
    assert_equal result.stdout, again.stdout
  end

  def test_vpn_config_preserves_settings_and_checks_certificates
    command = ['python3', ROOT / 'scripts/update-vpn.py', '192.0.2.1', 'vpn', 'ipsec']
    original = "# local settings\nuser-name=example\nignore-server-cert=true\n"
    result = capture(*command, input: original)
    assert_success result
    assert_includes result.stdout, 'user-name=example'
    assert_includes result.stdout, 'ignore-server-cert=false'
    assert_includes result.stdout, 'server-name=192.0.2.1'
    again = capture(*command, input: result.stdout)
    assert_success again
    assert_equal result.stdout, again.stdout
    refute_equal 0, capture(*command.take(2), "bad\nserver", 'vpn', 'ipsec').exitstatus
  end

  def test_interface_fallback_survives_route_failure
    result = bash(<<~'BASH')
      source ./functions
      ip() { if [[ $1 == route ]]; then return 2; else printf '2: enp1s0: <UP>\n'; fi; }
      active_interface 192.0.2.1
    BASH
    assert_success result
    assert_equal 'enp1s0', result.stdout.strip
  end

  def fixture
    folder = @temp / 'repo'
    folder.mkdir
    %w[migration functions ssh-config-template wsl-template.conf repository_locations.yml mise.toml].each do |name|
      FileUtils.cp(ROOT / name, folder / name, preserve: true)
    end
    FileUtils.cp_r(ROOT / 'scripts', folder / 'scripts')
    folder.glob('scripts/**/__pycache__').each { |path| FileUtils.remove_entry(path) }
    (folder / 'config').write("testFlag=true\ndotfiles=\"$HOME/dotfiles\"\ncloneRoot=\"$HOME/git\"\n")
    (folder / '10-test').write("if [[ ${testFlag:-false} != true ]]; then return 0; fi\nprintf run >> \"$HOME/runs\"\n")
    folder
  end

  def test_runner_dry_run_scope_and_resume_invalidation
    folder = fixture
    result = bash('./migration --dry-run', cwd: folder)
    assert_success result
    assert_includes result.stdout, 'Would run: 10-test'
    refute (@home / 'state').exist?
    refute_equal 0, bash('./migration --step config', cwd: folder).exitstatus
    assert_success bash('./migration', cwd: folder)
    assert_success bash('./migration --resume', cwd: folder)
    assert_equal 'run', (@home / 'runs').read
    (folder / 'ssh-config-template').open('a') { |stream| stream.write("\n# changed\n") }
    assert_success bash('./migration --resume', cwd: folder)
    assert_equal 'runrun', (@home / 'runs').read
    (folder / 'config').write("testFlag=false\ndotfiles=\"$HOME/dotfiles\"\ncloneRoot=\"$HOME/git\"\n")
    before = (@home / 'state/bootstrap-omarchy/migrations').children.sort
    assert_success bash('./migration --resume', cwd: folder)
    assert_equal before, (@home / 'state/bootstrap-omarchy/migrations').children.sort
  end

  def test_runner_continues_after_starship_decline_without_marking_it_complete
    folder = fixture
    FileUtils.cp(ROOT / '09-add-starship-prompt', folder / '09-add-starship-prompt')
    (folder / 'config').open('a') { |stream| stream.write("starshipFlag=true\n") }
    result = bash('./migration', cwd: folder, input: "N\n")
    assert_success result
    assert_includes result.stdout, '09-add-starship-prompt skipped by request; continuing'
    assert_equal 'run', (@home / 'runs').read
    markers = (@home / 'state/bootstrap-omarchy/migrations').children
    assert_equal 1, markers.length
    assert markers.first.basename.to_s.start_with?('10-test-')
    assert_success bash('./migration --resume', cwd: folder, input: "N\n")
    assert_equal 'run', (@home / 'runs').read
  end

  def test_runner_never_marks_failed_step_complete
    folder = fixture
    (folder / '10-test').open('a') { |stream| stream.write("false\n") }
    refute_equal 0, bash('./migration', cwd: folder).exitstatus
    assert_empty (@home / 'state/bootstrap-omarchy/migrations').children
  end

  def test_digest_changes_with_external_configuration
    folder = fixture
    (folder / '21-update-omarchy-shell').write('test')
    source = @home / 'dotfiles/omarchy/shell.json'
    source.parent.mkpath
    source.write('{}')
    command = ['python3', folder / 'scripts/migration-digest.py', folder, '21-update-omarchy-shell', @home / 'dotfiles', @home / 'git']
    before = capture(*command)
    assert_success before
    source.write('{"bar": {}}')
    after = capture(*command)
    assert_success after
    refute_equal before.stdout, after.stdout
  end
end
