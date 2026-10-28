# Atomator: remote Linux fleet management

An interactive Bash menu for maintaining Debian-based Linux machines over SSH.
The CLI and [Android app](https://github.com/axelsarassamit/atomator-android-app) are separate projects.

## Install a configured bundle

Source templates deliberately refuse to run until you configure your own site.
Download the complete repository, rather than an individual installer script:

```bash
git clone https://github.com/axelsarassamit/atomator.git
cd atomator
python3 configure_site.py --schema > site-settings.json
# Fill every replacement with your own account, domain and endpoint values.
python3 configure_site.py --config site-settings.json --output ../atomator-configured
sudo bash ../atomator-configured/run-configured.sh quick_install.sh
```

The installer validates file checksums and shell syntax, installs dependencies,
and installs the canonical scripts in `/remote_tools`. No scripts are generated
from embedded copies. `install_all_scripts.sh` and `create_all_scripts.sh` are
compatibility entry points for this same installer.

Requirements: Linux, Bash 4.4 or newer, Python 3.10 or newer, OpenSSH client,
GNU coreutils (including `timeout`), util-linux (`flock`), and optionally `sshpass` for password login.
The installer also installs `wakeonlan`, `bc`, `curl` and `git`. Managed hosts need
SSH and the packages used by the selected action. Package actions target `apt`;
desktop actions may require XFCE, NetworkManager, systemd, or a logged-in session.
These operations have offline regression coverage, not a certification across
all Debian-based distributions.

## Configure SSH access

1. Add hostnames or IPs to `/remote_tools/hosts.txt`, one per line. Blank lines,
   comments and duplicates are handled. Invalid entries stop the entire job.
2. Set `SSH_USER` in `/remote_tools/credentials.conf`. SSH keys or an SSH agent
   are preferred. `SSH_IDENTITY_FILE` and `SSH_PORT` are optional.
3. Populate `/remote_tools/known_hosts` with independently verified host keys.
   Unknown or changed keys fail. There is no automatic trust or bypass.
4. Configure the remote account's sudo policy independently. Administrative
   actions use `sudo -n`; Atomator never adds a privilege grant automatically.

Example credentials file:

```text
SSH_USER=operator
SSH_PORT=22
SSH_IDENTITY_FILE=/root/.ssh/fleet_ed25519
```

The file is parsed as data, never executed as shell code. Values can be literal
unquoted text or shell-quoted strings. Do not use shell expansions such as `$HOME`
in a path; use the absolute path. Keep the file private (`chmod 600`).

For password login, supply `SSH_PASSWORD` in the environment. `SSH_PASS` remains
accepted as a legacy authentication alias. Environment values take precedence
over file values; `SSH_PASSWORD` takes precedence over `SSH_PASS` at the same
level. A password authenticates SSH only: sudo remains noninteractive.
If starting via sudo, ensure the intended variables or SSH agent survive the
privilege change, or configure the root account's SSH key explicitly.

To collect a candidate key, use `ssh-keyscan`, inspect its fingerprint with
`ssh-keygen -lf`, and compare it through a trusted independent channel before
adding it to `known_hosts`. Collecting a key alone does not verify its identity.

## Run and preview actions

```bash
bash /remote_tools/run-configured.sh menu.sh

# Preview exactly which hosts would be targeted. Makes no connections.
bash /remote_tools/run-configured.sh update_all.sh --dry-run

# Select one or more inventory members.
bash /remote_tools/run-configured.sh update_all.sh --host desktop01 --host desktop02

# Alternate inventory and bounded parallelism.
bash /remote_tools/run-configured.sh update_all.sh --hosts-file /private/group.txt --parallel 3

# Retry hosts listed by a previous run. They must still belong to the inventory.
bash /remote_tools/run-configured.sh update_all.sh --retry-failed /remote_tools/reports/RUN/failed-hosts.txt

# Apply selection to fleet actions launched from the menu.
bash /remote_tools/run-configured.sh menu.sh --host desktop01 --parallel 2
```

Fleet actions show a host preview and request `yes` before connecting. `--yes`
skips that preview confirmation for automation. Existing operation-specific
confirmations, including watchdog installation and password rotation, still
apply. `--dry-run` ends after the host preview; it does not validate a remote
sudo policy or test remote prerequisites.

Most administrative jobs share a bounded worker pool (`MAX_PARALLEL`, default 5,
maximum 128). Existing tabular report collectors run sequentially to preserve
their report layouts. SSH uses a 10-second connection timeout and keepalives.
`ATOMATOR_TIMEOUT` sets the per-command timeout in seconds (default 1800).
A timeout or disconnected connection can leave a remote operation running;
inspect its state before retrying a mutating action.

Each fleet run saves private results under `reports/`:

- `results.tsv`: host, status and exit code.
- `failed-hosts.txt`: failed or incomplete hosts, suitable for an explicit retry.
- `errors/`: per-host transport errors.
- Per-host worker logs for parallel jobs, plus the selected inventory.

Jobs return nonzero if any host fails or is incomplete. Exit 64 indicates invalid
configuration or arguments; SSH failures commonly return 255 and timeouts 124.
The menu records the action's exit status instead of claiming every run succeeded.

## Menu features

- System updates, package cleanup, automatic-update configuration, reboot and shutdown.
- Host status, wake-on-LAN, MAC collection, DNS and static-IP configuration, WiFi controls,
  VPN removal, network restrictions, speed tests and an explicit HTTPS connectivity test.
- Hardware, RAM, disk, uptime, service reports and a fleet health summary.
- Software installation and removal, including an explicit APT package action.
- Wallpaper and Chromium CPU configuration.
- Custom commands, password rotation, file copying, session locking, terminal messages,
  local SSH-key cleanup and sudo repairs.
- Host-list management, saved reports and debug logs.

Messages use `wall` for logged-in terminal users. Screen locking uses
`loginctl lock-sessions`. File copies use the SSH account's permissions and
require a destination without spaces or shell characters; they do not elevate
privileges. Custom commands and deployment payloads are streamed over SSH stdin.

Password rotation also sends the new password over stdin, never inside a remote
shell command. It leaves the saved credential file unchanged on both success
and partial failure. Review `results.tsv`, reconcile failed hosts, then update
local authentication explicitly. Newlines and colons are not supported in passwords.

## Update and rollback

```bash
# Configure the new source into a separate directory, then install it.
bash /remote_tools/run-configured.sh update.sh --bundle /private/new-configured-bundle

# Download a pinned current-main revision, configure with private local site
# settings, then request installation confirmation.
bash /remote_tools/run-configured.sh update.sh --download

# Roll back code from a previous format-2 installation snapshot.
bash /remote_tools/run-configured.sh update.sh --bundle /remote_tools.backups/SNAPSHOT
```

Bundles carry SHA-256 checksums and are syntax-checked before installation.
Checksums detect file changes; obtain bundles from a trusted source. Installation
stages a complete directory, preserves runtime data, validates it, and switches
directories with rollback if activation fails. Concurrent installers are rejected.
Updates preserve host lists, credentials, verified keys, watchdog configuration,
MAC data, reports, and other existing runtime files. Old installations are retained
in a private sibling `remote_tools.backups` directory. Rollback restores code while
preserving the current runtime data. It does not undo changes made to remote hosts.

A source checkout includes historical updater scripts under `updates/`. They are
not packaged or selected automatically. Old single-file installers cannot serve
as format-2 rollback bundles. Preserve historical backups for manual inspection.
The first update from an older installation must use a newly configured bundle's
`quick_install.sh`, not the old installed updater.

`--download` requires Git and `.site-settings.json`, the private replacement map
retained by the configurator. It resolves main to a commit, fetches that commit,
and configures a separate bundle before installation. New schema requirements
must be filled explicitly. Shared packages exclude this private settings map;
installations made from those packages can update with a separately configured bundle.

For a custom location or a system with dependencies already installed:

```bash
bash ../atomator-configured/run-configured.sh quick_install.sh --target /opt/atomator --skip-dependencies
```

The default install creates `/root/start.sh`. Custom installations use their own
`run-configured.sh`. Failed operations return nonzero instead of printing an
unconditional update success message.

## Watchdog

The existing destructive connectivity watchdog remains available in menu `666`.
Its production payload, 72-hour default, timer controls and disk-overwrite action
are preserved. Installation remains explicit and requires its existing confirmation.
Configure at least two ping targets in `watchdog_hosts.conf` first. Additional
servers can be selected with `install_server_watchdog.sh --hosts-file /private/servers.txt`.
The test-mode watchdog remains separate. Installing the CLI never installs either
watchdog on remote machines automatically.

## Package and development

```bash
bash ../atomator-configured/run-configured.sh create_deployment_package.sh /private/atomator.tar.gz
python3 -m unittest discover -s tests -v
```

Packages contain the canonical scripts, shared libraries, defaults, documentation,
launcher and checksum manifest. They exclude local credentials, actual host lists,
keys, reports and the private settings map. Extract, inspect and use
`bash atomator/run-configured.sh quick_install.sh` on the target server.

Tests check inert source guards, configuration, menu targets, installation,
rollback, data preservation, partial failures, authentication, quoting and timeouts.
Fleet integration tests substitute local fake SSH commands. They do not contact
managed machines or execute deployment payloads. See [SITE_CONFIGURATION.md](SITE_CONFIGURATION.md).
