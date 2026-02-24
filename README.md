# The Automator - Remote Xubuntu Management

Manage multiple Xubuntu computers remotely from a central Debian server via SSH. One menu, 37 scripts, full control.

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

3. Edit your credentials (default: `sweetagent`/`sweetcom`):

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
SSH_USER=sweetagent
SSH_PASS=sweetcom
```

This file is:
- Created automatically on first install with default values
- **Never overwritten** by updates (your credentials are preserved)
- Set to mode 600 (readable only by root)
- Used by all 29 SSH-based scripts at runtime

**Change your credentials** by either:
- Editing the file directly: `nano /remote_tools/credentials.conf`
- Using the password change script: Main menu → 6. Tools → 3. Change remote password (updates both the remote machines and `credentials.conf`)

---

## How It Works

Every script follows the same pattern:

1. Loads credentials from `credentials.conf`
2. Reads IP addresses from `hosts.txt`
3. Connects to each host via SSH using the configured account
4. Runs commands with sudo on the remote machine
5. Reports success or failure for each host
6. Continues to the next host even if one fails

Lines starting with `#` in `hosts.txt` are ignored (comments). Empty lines are skipped.

---

## Menu Navigation

Start the menu:
```bash
bash /root/start.sh
# or
cd /remote_tools && bash menu.sh
```

The menu uses a **category-based submenu system**:

```
Main Menu
├── 1. System Updates & Maintenance  (6 options)
├── 2. Network                       (11 options)
├── 3. Information & Reports         (10 options)
├── 4. Software                      (5 options)
├── 5. Configuration                 (3 options)
├── 6. Tools                         (3 options)
├── 7. File Management               (4 options)
├── 8. Update Scripts
└── 0. Exit
```

Select a category by number, then choose an option from the submenu. Press `0` to go back to the main menu from any submenu.

The menu header shows:
- Current version number
- Number of hosts loaded from `hosts.txt`
- Install date

All menu navigation is logged to `debug.log` for troubleshooting.

---

## Scripts Reference

### 1. System Updates & Maintenance

| # | Script | Description |
|---|--------|-------------|
| 1 | `update_all.sh` | Runs `apt update`, `apt upgrade`, `autoremove` and `autoclean` on every host. Uses non-interactive mode to avoid prompts. Keeps existing config files when packages ask. |
| 2 | `update_and_remove_all.sh` | Same as option 1, but also purges old kernel packages to free disk space. |
| 3 | `disable_auto_updates.sh` | Stops and disables `unattended-upgrades` and all APT timers. Removes the unattended-upgrades package. Prevents systems from updating themselves unexpectedly. |
| 4 | `cleanup_all.sh` | Cleans APT cache, old journal logs (keeps 7 days), temp files older than 7 days, user trash and thumbnail cache. |
| 5 | `reboot.sh` | Reboots all hosts. Asks for confirmation before sending the command. |
| 6 | `shutdown_all.sh` | Shuts down all hosts. Asks for confirmation before sending the command. |

### 2. Network

| # | Script | Description |
|---|--------|-------------|
| 1 | `check_hosts.sh` | Pings every host and shows ONLINE (green) or OFFLINE (red). Shows totals at the end. Does not require SSH. |
| 2 | `wol_all.sh` | Sends Wake-on-LAN magic packets to wake up powered-off computers. Reads MAC addresses from `mac_addresses.txt`. Sends 3 packets per host. Run `collect_mac_addresses.sh` first. |
| 3 | `collect_mac_addresses.sh` | Connects to each host, reads the MAC address of the primary ethernet interface, and saves it to `mac_addresses.txt`. Required before using Wake-on-LAN. |
| 4 | View MAC addresses | Displays the contents of `mac_addresses.txt`. |
| 5 | `change_dns.sh` | Sets DNS servers to Cloudflare (1.1.1.1), Google (8.8.8.8), and Quad9 (9.9.9.9) on all hosts. Disables auto-DNS from DHCP. Uses NetworkManager. |
| 6 | `fix_static_ip.sh` | Reads the current DHCP-assigned IP and converts it to a permanent static IP. Keeps the same address, gateway and DNS. Uses NetworkManager. |
| 7 | `remove_vpn_reset_network.sh` | Removes all VPN packages (OpenVPN, WireGuard, etc.), deletes VPN connections, cleans config files, and sets the current IP as static. Full network reset. |
| 8 | `require_sudo_network.sh` | Installs a polkit rule that requires a sudo password to change any network settings. Prevents users from modifying network configuration. |
| 9 | `speedtest_all.sh` | Installs `speedtest-cli` if missing, then runs a speed test on every host. Saves results with timestamps to a file. |
| 10 | View latest speed test | Displays the most recent speed test results file. |
| 11 | `disable_wifi.sh` | Permanently disables WiFi: turns off radio, blocks with rfkill, blacklists common WiFi kernel modules, and configures NetworkManager to ignore WiFi devices. |

### 3. Information & Reports

Each data collection script saves results to a timestamped file. Use the "View latest" option to see the most recent report without re-running the collection.

| # | Script | Description |
|---|--------|-------------|
| 1 | `collect_hardware_info.sh` | Collects hostname, manufacturer, model, serial number, CPU, core count, RAM, disk size, OS version, kernel, and uptime from every host. Saves to `hardware_info_YYYYMMDD_HHMMSS.txt`. |
| 2 | View latest hardware report | Displays the most recent hardware info file. |
| 3 | `collect_ram_info.sh` | Collects detailed RAM information (total, used, free) from every host. Shows a summary with totals and averages. Saves to `ram_info_YYYYMMDD_HHMMSS.txt`. |
| 4 | View latest RAM report | Displays the most recent RAM info file. |
| 5 | `check_disk_space.sh` | Shows disk usage percentage for every host with color coding: green (under 80%), yellow (80-90% WARNING), red (over 90% CRITICAL). Saves to `disk_space_YYYYMMDD_HHMMSS.txt`. |
| 6 | View latest disk report | Displays the most recent disk space file. |
| 7 | `check_uptime.sh` | Shows how long each host has been running and when it was last booted. Saves to `uptime_YYYYMMDD_HHMMSS.txt`. |
| 8 | View latest uptime report | Displays the most recent uptime file. |
| 9 | `check_services.sh` | Checks if key services are running on every host: SSH, NetworkManager, cron, and rsyslog. Shows OK or FAIL for each service. Saves to `services_YYYYMMDD_HHMMSS.txt`. |
| 10 | View latest services report | Displays the most recent services file. |

### 4. Software

| # | Script | Description |
|---|--------|-------------|
| 1 | `install_firefox.sh` | Installs Firefox (or Firefox ESR as fallback) and creates a desktop shortcut for all users. |
| 2 | `uninstall_firefox.sh` | Removes Firefox and locale packages. User profiles in `~/.mozilla` are kept. |
| 3 | `install_hostname_display.sh` | Installs Conky and creates a configuration that displays the computer's hostname in the bottom-right corner of the desktop. Auto-starts on login. Useful for identifying which computer you're looking at. |
| 4 | `install_wine.sh` | Installs Wine (32-bit and 64-bit) and Winetricks for running Windows .exe files. |
| 5 | `remove_wine.sh` | Removes Wine packages and deletes all `~/.wine` directories. |

### 5. Configuration

| # | Script | Description |
|---|--------|-------------|
| 1 | `set_wallpaper.sh` | Picks a random URL from `wallpapers.txt`, downloads the image, and sets it as wallpaper for all users on all hosts. Works with XFCE desktop. Create a `wallpapers.txt` file with one image URL per line. |
| 2 | `restrict_chromium_cpu.sh` | Installs `cpulimit` and creates a systemd service that limits all Chromium processes to 50% CPU. Prevents Chromium from eating all system resources. Starts automatically on boot. |
| 3 | `manage_wallpapers.sh` | Interactive menu to manage `wallpapers.txt`: add URLs, remove entries, view current list, or clear all. |

### 6. Tools

| # | Script | Description |
|---|--------|-------------|
| 1 | `run_remote_command.sh` | Prompts you for a command, then runs it as root on every host. Full output is shown for each host. Use this for one-off commands you don't have a script for. |
| 2 | `delete_ssh_keys.sh` | Deletes all SSH keys for all users and root on **this server only** (not remote hosts). Clears known_hosts and authorized_keys, then regenerates the host keys. Asks for confirmation. |
| 3 | `change_password.sh` | Changes the SSH user's password on all remote hosts. Asks for the new password (with confirmation), updates each host, then saves the new password to `credentials.conf`. |

### 7. File Management

| # | Option | Description |
|---|--------|-------------|
| 1 | Manage hosts.txt | Interactive submenu: fill with an IP range, add/remove individual hosts, remove duplicates, sort, count, or restore from backup. |
| 2 | View hosts.txt | Displays the contents of `hosts.txt` with line numbers. |
| 3 | Edit hosts.txt | Opens `hosts.txt` in nano (or your default editor). |
| 4 | View README | Displays the README documentation using `less`. |

### 8. Update Scripts

Runs `update.sh` which gives you three options:
1. **Update from local file** - Uses an update file already in `/remote_tools/updates/`
2. **Download latest from GitHub** - Downloads the latest version directly from the repository
3. **Revert to a previous version** - Lists all stored versions in `updates/` and lets you pick one to revert to

The update process shows a changelog of what changed between your current version and the new version.

See [Updating](#updating) for details.

---

## Report Viewers

Several scripts generate timestamped report files when they run. Instead of re-running a collection (which takes time connecting to every host), you can instantly view the latest report from the menu.

**Reports available:**

| Report | File Pattern | Menu Location |
|--------|-------------|---------------|
| Hardware info | `hardware_info_*.txt` | Information & Reports → 2 |
| RAM info | `ram_info_*.txt` | Information & Reports → 4 |
| Disk space | `disk_space_*.txt` | Information & Reports → 6 |
| Uptime | `uptime_*.txt` | Information & Reports → 8 |
| Services | `services_*.txt` | Information & Reports → 10 |
| MAC addresses | `mac_addresses.txt` | Network → 4 |
| Speed test | `speedtest_results_*.txt` | Network → 10 |

Report files accumulate over time. Old reports are not automatically deleted. You can remove them manually if needed.

---

## Managing Hosts

### hosts.txt Format

One IP address per line. Lines starting with `#` are comments and ignored:

```
# Office computers - Building A
192.168.1.50
192.168.1.51
192.168.1.52

# Lab computers
192.168.1.100
192.168.1.101
```

### Adding Hosts

**Option A** - Fill a range (Main menu → File Management → Manage hosts.txt):
```
Enter IP range (e.g. 192.168.1.50-199): 192.168.1.50-75
```
This creates 26 entries from 192.168.1.50 to 192.168.1.75.

**Option B** - Edit manually (Main menu → File Management → Edit hosts.txt):
Opens the file in nano where you can type IPs directly.

**Option C** - Add one at a time (Main menu → File Management → Manage hosts.txt → Add host):
```
IP to add: 192.168.1.200
```

### Verifying Hosts

After adding hosts, use Network → Check host status to see which are online and reachable.

---

## Updating

### How to Update

**Option 1: Download from GitHub (recommended)**

1. Open the menu: `bash /root/start.sh`
2. Choose option **8** (Update Scripts)
3. Choose option **2** (Download latest from GitHub)
4. Review the version comparison and changelog, then confirm

Or run directly:
```bash
cd /remote_tools && bash update.sh
```

**Option 2: Update from local file**

1. Get the new `quick_install.sh`
2. Copy it to the server's updates directory:
   ```bash
   scp quick_install.sh root@your-server:/remote_tools/updates/
   ```
3. Run the update from the menu (option 8) or directly:
   ```bash
   cd /remote_tools && bash update.sh
   ```

**Option 3: Revert to a previous version**

1. Open the menu: `bash /root/start.sh`
2. Choose option **8** (Update Scripts)
3. Choose option **3** (Revert to a previous version)
4. Pick from the list of stored versions in `updates/`

### Update Catalog

Every update is stored in the `updates/` directory. This means you can always roll back to any previous version. Files are named `update_v.XX.YY.AA.sh` (e.g. `update_v.02.01.00.sh`).

### What Happens During Update

1. Shows your current version and install date
2. Lets you choose local file, GitHub download, or revert
3. Shows version comparison and changelog between versions
4. Asks for confirmation
5. Backs up `hosts.txt`, `mac_addresses.txt`, `wallpapers.txt`, and `credentials.conf`
6. Runs the new installer (overwrites all scripts)
7. Restores config files if they were lost
8. Stores the update file in `updates/` for future reverts

### Version Tracking

The file `version.txt` in `/remote_tools/` contains:
- Line 1: Version number (e.g. `02.01.00`)
- Line 2: Install date and time

The menu header always shows the current version and install date.

### What's Preserved on Update

These files are **never overwritten** by the installer:
- `hosts.txt` (your IP list)
- `mac_addresses.txt` (collected MAC addresses)
- `wallpapers.txt` (your wallpaper URLs)
- `credentials.conf` (your SSH credentials)
- `watchdog_hosts.conf` (your watchdog ping hosts)

Everything else (all scripts, menu, update.sh) is regenerated fresh.

---

## Debug Logging

All menu navigation is logged to `/remote_tools/debug.log` with timestamps:

```
[2026-02-24 10:15:32] MENU: main > choice=1 (System Updates)
[2026-02-24 10:15:35] SUBMENU: updates > choice=1 (Update All)
[2026-02-24 10:15:35] Running script: update_all.sh
[2026-02-24 10:20:12] Script finished: update_all.sh
```

The log file automatically rotates at 10MB (old log saved as `debug.log.1`). Only menu navigation and script start/finish events are logged, not script output.

---

## File Structure

After installation, `/remote_tools/` contains:

```
/remote_tools/
  credentials.conf                 # SSH credentials (mode 600, root only)
  hosts.txt                        # Your target IPs (created on first install)
  mac_addresses.txt                # Collected MAC addresses (after running collection)
  wallpapers.txt                   # Wallpaper URLs (create manually)
  watchdog_hosts.conf              # Watchdog ping host configuration
  version.txt                      # Current version + install date
  CHANGELOG.md                     # Version history with changes
  README.md                        # This documentation (viewable from menu)
  debug.log                        # Menu navigation log (auto-created)
  menu.sh                          # Interactive menu with submenus
  update.sh                        # Update script (local + GitHub + revert)
  updates/                         # Update catalog (versioned install files)
    update_v.02.01.00.sh           #   Stored installer for each version
  update_all.sh                    # System update
  update_and_remove_all.sh         # System update + kernel cleanup
  disable_auto_updates.sh          # Disable unattended-upgrades
  cleanup_all.sh                   # System cleanup
  reboot.sh                        # Reboot all hosts
  shutdown_all.sh                  # Shutdown all hosts
  check_hosts.sh                   # Ping all hosts
  wol_all.sh                       # Wake-on-LAN
  collect_mac_addresses.sh         # Collect MAC addresses
  change_dns.sh                    # Change DNS servers
  fix_static_ip.sh                 # Fix static IP
  remove_vpn_reset_network.sh      # Remove VPN + reset network
  require_sudo_network.sh          # Lock network settings
  speedtest_all.sh                 # Speed test all hosts
  disable_wifi.sh                  # Disable WiFi
  collect_hardware_info.sh         # Collect hardware info
  collect_ram_info.sh              # Collect RAM info
  check_disk_space.sh              # Check disk space
  check_uptime.sh                  # Check uptime
  check_services.sh                # Check services
  install_firefox.sh               # Install Firefox
  uninstall_firefox.sh             # Uninstall Firefox
  install_hostname_display.sh      # Install hostname display
  install_wine.sh                  # Install Wine
  remove_wine.sh                   # Remove Wine
  set_wallpaper.sh                 # Set wallpaper
  manage_wallpapers.sh             # Manage wallpaper URLs
  restrict_chromium_cpu.sh         # Restrict Chromium CPU
  run_remote_command.sh            # Run custom command
  delete_ssh_keys.sh               # Delete SSH keys (local)
  change_password.sh               # Change remote password
  manage_hosts.sh                  # Manage hosts.txt
  install_connectivity_watchdog.sh # Install network watchdog
  remove_connectivity_watchdog.sh  # Remove network watchdog
  check_watchdog_status.sh         # Check watchdog status
  configure_watchdog_hosts.sh      # Configure watchdog ping hosts

/root/
  start.sh                         # Quick launcher: cd /remote_tools && bash menu.sh
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| v.02.01.00 | 2026-02-24 | Renamed to "The Automator". New version format v.XX.YY.AA. Credentials system (`credentials.conf`) replaces hardcoded passwords. Password change script. Debug menu logging. Update catalog with version revert. Changelog display on updates. Wallpaper management script. Watchdog host configuration. View README from menu. Fixed: sudo command not found in update menu. |
| v.02.00.00 | 2026-02-23 | Submenu system (8 categories), report viewers for all data collectors, GitHub update support, delete SSH keys now local-only, timestamped output files for disk/uptime/services scripts. |
| v.01.00.00 | 2026-02-23 | Complete rewrite. 34 scripts, new menu with descriptions, version system, update mechanism. Added shutdown, disk space, uptime, services scripts. Consistent error handling across all scripts. |
