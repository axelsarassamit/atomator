# Atomator - Remote Xubuntu Management

Manage multiple Xubuntu computers remotely from a central Debian server via SSH. One menu, 37 scripts, full control. All operations run in parallel for maximum speed.

## Quick Start

```bash
# On your Debian server (as root):
sudo bash quick_install.sh

# Start the menu:
bash /root/start.sh
```

That's it. All 37 scripts are installed to `/remote_tools/`, ready to use.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [Credentials](#credentials)
- [How It Works](#how-it-works)
- [Menu Navigation](#menu-navigation)
- [Scripts Reference](#scripts-reference)
  - [System Updates & Maintenance](#1-system-updates--maintenance)
  - [Network](#2-network)
  - [Information & Reports](#3-information--reports)
  - [Software](#4-software)
  - [Configuration](#5-configuration)
  - [Tools](#6-tools)
  - [File Management](#7-file-management)
  - [Update Scripts](#8-update-scripts)
- [Report Viewers](#report-viewers)
- [Managing Hosts](#managing-hosts)
- [Updating](#updating)
- [Debug Logging](#debug-logging)
- [File Structure](#file-structure)
- [Version History](#version-history)

---

## Requirements

**Server (where you run the scripts):**
- Debian or Ubuntu based system
- Root access
- Network access to all target computers

**Target computers:**
- Xubuntu (or any Ubuntu/Debian based distro)
- SSH enabled
- A user account with sudo privileges (configured in `credentials.conf`)
- NetworkManager for network scripts

**Installed automatically by the installer:**
- `sshpass` - SSH password authentication
- `wakeonlan` - Wake-on-LAN packets
- `bc` - Calculator for scripts
- `curl` - HTTP requests

---

## Installation

### Fresh Install

1. Copy `quick_install.sh` to your Debian server
2. Run as root:

```bash
sudo bash quick_install.sh
```

3. Edit your credentials (default: `XXXXXXX`/`XXXXXXX`):

```bash
nano /remote_tools/credentials.conf
```

4. Add your target computer IPs:

```bash
bash /root/start.sh
# Main menu -> 7. File Management -> 1. Manage hosts.txt
```

5. Test connectivity:

```bash
# Main menu -> 2. Network -> 1. Check host status
```

### What the Installer Does

- Creates `/remote_tools/` directory
- Installs required packages (sshpass, wakeonlan, bc, curl)
- Generates all 37 management scripts
- Creates the interactive menu (`menu.sh`) with submenus
- Creates `/root/start.sh` for quick launch
- Creates `credentials.conf` with SSH credentials (mode 600, root only)
- Creates `watchdog_hosts.conf` for connectivity watchdog settings
- Creates `version.txt` with version number and install date
- Creates `updates/` directory and stores the installer for future reverts
- Creates `CHANGELOG.md` with version history
- Creates `README.md` viewable from the menu
- Sets directory permissions to 700 (root only)
- Preserves existing `hosts.txt`, `credentials.conf`, `wallpapers.txt`, and `mac_addresses.txt` if upgrading

---

## Credentials

SSH credentials are stored in `/remote_tools/credentials.conf`:

```
SSH_USER=XXXXXXX
SSH_PASS=XXXXXXX
```

This file is:
- Created automatically on first install with default values
- **Never overwritten** by updates (your credentials are preserved)
- Set to mode 600 (readable only by root)
- Used by all 29 SSH-based scripts at runtime

**Change your credentials** by either:
- Editing the file directly: `nano /remote_tools/credentials.conf`
- Using the password change script: Main menu -> 6. Tools -> 3. Change remote password (updates both the remote machines and `credentials.conf`)

---

## How It Works

Every script follows the same pattern:

1. Loads credentials from `credentials.conf`
2. Reads IP addresses from `hosts.txt`
3. Connects to each host **in parallel** via SSH using the configured account
4. Runs commands with `sudo` using the configured password
5. Reports results with OK/FAILED status and elapsed time

### Parallel Execution

All scripts run SSH commands in parallel (background jobs with controlled concurrency):

- Default parallelism: 5 jobs for write operations, 10 for read-only checks
- Override with environment variable: `export MAX_PARALLEL=20`
- Results are collected and displayed in order after all jobs complete
- Temp files are automatically cleaned up via `trap` on exit

Lines starting with `#` in `hosts.txt` are ignored (comments). Empty lines are skipped.

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v.02.08.02 | 2026-05-08 | New update mechanism: downloads individual files from GitHub instead of monolithic installer. Instant updates on every push. |
| v.02.08.01 | 2026-05-08 | Complete UI redesign: modern TUI with icons, box drawing, branded header, status bar. |
| v.02.08.00 | 2026-05-08 | Performance: all scripts now execute in parallel (configurable via MAX_PARALLEL env var). Up to 10x faster on large fleets. Added elapsed time, progress counters, ServerAliveInterval, and consistent result summaries. |
| v.02.07.04 | 2026-02-27 | Fix hostname display: proper restart without reboot - kills old conky cleanly then starts fresh. |
| v.02.07.03 | 2026-02-27 | Fixed black background: enables Xfce compositor for true ARGB transparency on hostname display. |
| v.02.07.02 | 2026-02-27 | Hostname display: black outline on white text, positioned closer to taskbar. |
| v.02.07.01 | 2026-02-27 | Fixed duplicate hostname display and black background. |
| v.02.07.00 | 2026-02-27 | Redesigned all menus with section dividers and descriptions. |
| v.02.06.02 | 2026-02-27 | Fixed fix_hostname_display.sh hanging. |
| v.02.06.01 | 2026-02-27 | Improved fix_slow_sudo.sh. |
| v.02.06.00 | 2026-02-27 | Added Chrome, Chromium, Xpad install/remove. |
| v.02.05.01 | 2026-02-27 | Added fix_hostname_display.sh. |
| v.02.05.00 | 2026-02-27 | Added fix_slow_sudo.sh. |
| v.02.04.01 | 2026-02-27 | Fixed GitHub update cache delay. |
| v.02.04.00 | 2026-02-27 | Added Simplenote and Redshift. |
| v.02.03.03 | 2026-02-25 | check_hosts.sh shows hostname. |
| v.02.03.02 | 2026-02-25 | Changelog reversed order. |
| v.02.03.01 | 2026-02-25 | Update screen shows new changelog. |
| v.02.03.00 | 2026-02-25 | Static IP from hostname digits. |
| v.02.02.01 | 2026-02-25 | Custom DNS options. |
| v.02.02.00 | 2026-02-24 | Standardized TSV report format. |
| v.02.01.01 | 2026-02-24 | Fixed VPN removal DNS wipe. |
| v.02.01.00 | 2026-02-24 | Renamed to Atomator. Credentials system. Version format. |
| v.02.00.00 | 2026-02-23 | Submenu system, report viewers, GitHub updates. |
| v.01.00.00 | 2026-02-23 | Initial complete rewrite. 34 scripts. |
