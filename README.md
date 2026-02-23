# Atomator - Remote Xubuntu Management

Manage multiple Xubuntu computers remotely from a central Debian server via SSH. One menu, 34 scripts, full control.

## Quick Start

```bash
# On your Debian server (as root):
sudo bash quick_install.sh

# Start the menu:
bash /root/start.sh
```

That's it. All 34 scripts are installed to `/remote_tools/`, ready to use.

---

## Table of Contents

- [Requirements](#requirements)
- [Installation](#installation)
- [How It Works](#how-it-works)
- [Menu Overview](#menu-overview)
- [Scripts Reference](#scripts-reference)
  - [System Updates (1-3)](#system-updates)
  - [System Maintenance (4-6)](#system-maintenance)
  - [Network (7-15)](#network)
  - [Information (16-20)](#information)
  - [Software (21-25)](#software)
  - [Configuration (26-27)](#configuration)
  - [Tools (28-29)](#tools)
  - [File Management (30-32)](#file-management)
  - [Update (33)](#update)
- [Managing Hosts](#managing-hosts)
- [Updating](#updating)
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
- User account: `sweetagent` with sudo privileges
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

3. Add your target computer IPs:

```bash
bash /root/start.sh
# Choose option 30 (Manage hosts.txt) or option 32 (Edit hosts.txt)
```

4. Test connectivity:

```bash
# Choose option 7 (Check host status)
```

### What the Installer Does

- Creates `/remote_tools/` directory
- Installs required packages (sshpass, wakeonlan, bc, curl)
- Generates all 34 management scripts
- Creates the interactive menu (`menu.sh`)
- Creates `/root/start.sh` for quick launch
- Creates `version.txt` with version number and install date
- Creates `update_vX.X.X.sh` for future re-installs
- Sets directory permissions to 700 (root only)
- Preserves existing `hosts.txt` if upgrading

---

## How It Works

Every script follows the same pattern:

1. Reads IP addresses from `hosts.txt`
2. Connects to each host via SSH using the `sweetagent` account
3. Runs commands with sudo on the remote machine
4. Reports `[IP] OK` or `[IP] FAILED` for each host
5. Continues to the next host even if one fails

**Connection method:**
```
sshpass -> SSH -> sweetagent@host -> sudo -> command
```

Lines starting with `#` in `hosts.txt` are ignored (comments). Empty lines are skipped.

---

## Menu Overview

Start the menu with:
```bash
bash /root/start.sh
# or
cd /remote_tools && bash menu.sh
```

The menu shows:
- Current version number
- Number of hosts loaded from `hosts.txt`
- Install date
- All options organized by category

Choose an option by typing its number and pressing Enter.

---

## Scripts Reference

### System Updates

| # | Script | Description |
|---|--------|-------------|
| 1 | `update_all.sh` | Runs `apt update`, `apt upgrade`, `autoremove` and `autoclean` on every host. Uses non-interactive mode to avoid prompts. Keeps existing config files when packages ask. |
| 2 | `update_and_remove_all.sh` | Same as option 1, but also purges old kernel packages to free disk space. |
| 3 | `disable_auto_updates.sh` | Stops and disables `unattended-upgrades` and all APT timers. Removes the unattended-upgrades package. Prevents systems from updating themselves unexpectedly. |

### System Maintenance

| # | Script | Description |
|---|--------|-------------|
| 4 | `cleanup_all.sh` | Cleans APT cache, old journal logs (keeps 7 days), temp files older than 7 days, user trash and thumbnail cache. |
| 5 | `reboot.sh` | Reboots all hosts. **Asks for confirmation** before sending the command. |
| 6 | `shutdown_all.sh` | Shuts down all hosts. **Asks for confirmation** before sending the command. |

### Network

| # | Script | Description |
|---|--------|-------------|
| 7 | `check_hosts.sh` | Pings every host and shows **ONLINE** (green) or **OFFLINE** (red). Shows totals at the end. Does not require SSH. |
| 8 | `wol_all.sh` | Sends Wake-on-LAN magic packets to wake up powered-off computers. Reads MAC addresses from `mac_addresses.txt`. Sends 3 packets per host for reliability. Run `collect_mac_addresses.sh` first. |
| 9 | `collect_mac_addresses.sh` | Connects to each host, reads the MAC address of the primary ethernet interface, and saves it to `mac_addresses.txt`. Required before using Wake-on-LAN. |
| 10 | `change_dns.sh` | Sets DNS servers to Cloudflare (1.1.1.1), Google (8.8.8.8), and Quad9 (9.9.9.9) on all hosts. Disables auto-DNS from DHCP. Uses NetworkManager. |
| 11 | `fix_static_ip.sh` | Reads the current DHCP-assigned IP and converts it to a permanent static IP. Keeps the same address, gateway and DNS. Uses NetworkManager. |
| 12 | `remove_vpn_reset_network.sh` | Removes all VPN packages (OpenVPN, WireGuard, etc.), deletes VPN connections, cleans config files, and sets the current IP as static. Full network reset. |
| 13 | `require_sudo_network.sh` | Installs a polkit rule that requires a sudo password to change any network settings. Prevents users from modifying network configuration. |
| 14 | `speedtest_all.sh` | Installs `speedtest-cli` if missing, then runs a speed test on every host. Saves results with timestamps to a file. |
| 15 | `disable_wifi.sh` | Permanently disables WiFi: turns off radio, blocks with rfkill, blacklists common WiFi kernel modules, and configures NetworkManager to ignore WiFi devices. |

### Information

| # | Script | Description |
|---|--------|-------------|
| 16 | `collect_hardware_info.sh` | Collects hostname, manufacturer, model, serial number, CPU, core count, RAM, disk size, OS version, kernel, and uptime from every host. Saves to a timestamped report file. |
| 17 | `collect_ram_info.sh` | Collects detailed RAM information (total, used, free) from every host. Shows a summary with total RAM across all hosts and average per host. Saves to a timestamped report file. |
| 18 | `check_disk_space.sh` | Shows disk usage percentage for every host with color coding: **green** (under 80%), **yellow** (80-90% WARNING), **red** (over 90% CRITICAL). Quick way to find hosts running out of space. |
| 19 | `check_uptime.sh` | Shows how long each host has been running and when it was last booted. |
| 20 | `check_services.sh` | Checks if key services are running on every host: SSH, NetworkManager, cron, and rsyslog. Shows OK or FAIL for each service. |

### Software

| # | Script | Description |
|---|--------|-------------|
| 21 | `install_firefox.sh` | Installs Firefox (or Firefox ESR as fallback) and creates a desktop shortcut for all users. |
| 22 | `uninstall_firefox.sh` | Removes Firefox and locale packages. User profiles in `~/.mozilla` are kept. |
| 23 | `install_hostname_display.sh` | Installs Conky and creates a configuration that displays the computer's hostname in the bottom-right corner of the desktop. Auto-starts on login. Useful for identifying which computer you're looking at. |
| 24 | `install_wine.sh` | Installs Wine (32-bit and 64-bit) and Winetricks for running Windows .exe files. |
| 25 | `remove_wine.sh` | Removes Wine packages and deletes all `~/.wine` directories. |

### Configuration

| # | Script | Description |
|---|--------|-------------|
| 26 | `set_wallpaper.sh` | Picks a random URL from `wallpapers.txt`, downloads the image, and sets it as wallpaper for all users on all hosts. Works with XFCE desktop. Create a `wallpapers.txt` file with one image URL per line. |
| 27 | `restrict_chromium_cpu.sh` | Installs `cpulimit` and creates a systemd service that limits all Chromium processes to 50% CPU. Prevents Chromium from eating all system resources. Starts automatically on boot. |

### Tools

| # | Script | Description |
|---|--------|-------------|
| 28 | `run_remote_command.sh` | Prompts you for a command, then runs it as root on every host. Full output is shown for each host. Use this for one-off commands you don't have a script for. |
| 29 | `delete_ssh_keys.sh` | Deletes all SSH keys for all users and root, clears known_hosts and authorized_keys, then regenerates the host keys. **Asks for confirmation.** |

### File Management

| # | Script | Description |
|---|--------|-------------|
| 30 | `manage_hosts.sh` | Interactive submenu for managing `hosts.txt`: fill with an IP range, add/remove individual hosts, remove duplicates, sort, count, or restore from backup. |
| 31 | View hosts.txt | Displays the contents of `hosts.txt` with line numbers. |
| 32 | Edit hosts.txt | Opens `hosts.txt` in nano (or your default editor). |

### Update

| # | Script | Description |
|---|--------|-------------|
| 33 | `update.sh` | Updates the installation to a new version. Looks for an `update_vX.X.X.sh` file in `/remote_tools/`, shows current vs new version, backs up your config files, runs the installer, and restores configs if needed. See [Updating](#updating). |

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

**Option A** - Fill a range (menu option 30):
```
Enter IP range (e.g. 192.168.1.50-199): 192.168.1.50-75
```
This creates 26 entries from 192.168.1.50 to 192.168.1.75.

**Option B** - Edit manually (menu option 32):
Opens the file in nano where you can type IPs directly.

**Option C** - Add one at a time (menu option 30, then sub-option 3):
```
IP to add: 192.168.1.200
```

### Verifying Hosts

After adding hosts, use option 7 (Check host status) to see which are online and reachable.

---

## Updating

### How to Update

1. **Get the new version**: Download or receive the new `quick_install.sh`
2. **Rename it** with the version number:
   ```bash
   mv quick_install.sh update_v1.1.0.sh
   ```
3. **Copy it to the server**:
   ```bash
   scp update_v1.1.0.sh root@your-server:/remote_tools/
   ```
4. **Run the update** from the menu (option 33) or directly:
   ```bash
   cd /remote_tools && sudo bash update.sh
   ```

### What Happens During Update

1. Shows your current version and install date
2. Detects the new version from the filename
3. Asks for confirmation
4. Backs up `hosts.txt`, `mac_addresses.txt`, and `wallpapers.txt`
5. Runs the new installer (overwrites all scripts)
6. Restores config files if they were lost
7. Keeps the update file for future re-installs

### Version Tracking

The file `version.txt` in `/remote_tools/` contains:
- Line 1: Version number (e.g. `1.0.0`)
- Line 2: Install date and time

The menu header always shows the current version and install date.

### What's Preserved on Update

These files are **never overwritten** by the installer:
- `hosts.txt` (your IP list)
- `mac_addresses.txt` (collected MAC addresses)
- `wallpapers.txt` (your wallpaper URLs)

Everything else (all scripts, menu, update.sh) is regenerated fresh.

---

## File Structure

After installation, `/remote_tools/` contains:

```
/remote_tools/
  hosts.txt                        # Your target IPs (created on first install)
  mac_addresses.txt                # Collected MAC addresses (after running option 9)
  wallpapers.txt                   # Wallpaper URLs (create manually)
  version.txt                      # Current version + install date
  menu.sh                          # Interactive menu
  update.sh                        # Update script
  update_v1.0.0.sh                 # Install file (kept for re-installs)
  update_all.sh                    # Script 1
  update_and_remove_all.sh         # Script 2
  disable_auto_updates.sh          # Script 3
  cleanup_all.sh                   # Script 4
  reboot.sh                        # Script 5
  shutdown_all.sh                  # Script 6
  check_hosts.sh                   # Script 7
  wol_all.sh                       # Script 8
  collect_mac_addresses.sh         # Script 9
  change_dns.sh                    # Script 10
  fix_static_ip.sh                 # Script 11
  remove_vpn_reset_network.sh      # Script 12
  require_sudo_network.sh          # Script 13
  speedtest_all.sh                 # Script 14
  disable_wifi.sh                  # Script 15
  collect_hardware_info.sh         # Script 16
  collect_ram_info.sh              # Script 17
  check_disk_space.sh              # Script 18
  install_firefox.sh               # Script 19/21
  uninstall_firefox.sh             # Script 20/22
  install_hostname_display.sh      # Script 23
  install_wine.sh                  # Script 24
  remove_wine.sh                   # Script 25
  set_wallpaper.sh                 # Script 26
  restrict_chromium_cpu.sh         # Script 27
  run_remote_command.sh            # Script 28
  delete_ssh_keys.sh               # Script 29
  manage_hosts.sh                  # Script 30
  install_connectivity_watchdog.sh # Watchdog install
  remove_connectivity_watchdog.sh  # Watchdog remove
  check_watchdog_status.sh         # Watchdog status

/root/
  start.sh                         # Quick launcher: cd /remote_tools && bash menu.sh
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2026-02-23 | Complete rewrite. 34 scripts, new menu with descriptions, version system, update mechanism. Added shutdown, disk space, uptime, services scripts. Consistent error handling across all scripts. |
