# Remote Xubuntu Management Scripts

This repository contains a collection of bash scripts for remotely managing multiple Xubuntu devices from a central Debian server.

## Table of Contents

- [Interactive Menu System](#interactive-menu-system)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Scripts Overview](#scripts-overview)
  - [System Updates](#system-updates)
  - [System Maintenance](#system-maintenance)
  - [Network Management](#network-management)
  - [Hardware Information](#hardware-information)
  - [Desktop Customization](#desktop-customization)
  - [Application Management](#application-management)
  - [System Monitoring](#system-monitoring)
  - [Power Management](#power-management)
  - [Utilities](#utilities)
  - [Security & Access Control](#security--access-control)

---

## Interactive Menu System

### menu.sh
**Purpose**: User-friendly interactive menu to run all scripts

**What it does**:
1. Displays a color-coded menu with all available scripts
2. Organizes scripts into logical categories
3. Allows you to select scripts by number
4. Shows descriptions for each script
5. Validates script existence before running
6. Returns to menu after each script completes

**Features**:
- 21 scripts organized into 6 categories
- Color-coded sections for easy navigation
- Built-in error checking
- View and edit hosts.txt from menu
- One-command access to all tools

**Usage**:
```bash
chmod +x menu.sh
./menu.sh
```

**Menu Categories**:
1. **System Updates** (1-3) - Update and manage system updates
2. **System Maintenance** (4-5) - Cleanup and reboot
3. **Network Management** (6-12) - Network configuration, WOL, testing
4. **Hardware Information** (13-14) - Collect system specs
5. **Software Installation** (15-16) - Install applications
6. **System Configuration** (17-18) - Wallpapers, CPU limits
7. **Utilities** (19-21) - Custom commands, view/edit hosts

**Why use the menu?**:
- No need to remember script names
- Descriptions remind you what each script does
- Organized by function for quick access
- Perfect for infrequent users
- Professional interface

---

## Prerequisites

### Server Requirements (Debian)
- `sshpass` package installed: `sudo apt install sshpass`
- SSH access to all target devices
- `hosts.txt` file with target IP addresses

### Client Requirements (Xubuntu)
- SSH server running
- User account: `sweetagent`
- Password: `sweetcom` (for both SSH and sudo)
- NetworkManager installed (standard on Xubuntu)

---

## Configuration

### hosts.txt File

All scripts read from a `hosts.txt` file in the same directory. Format:
```
192.168.1.50
192.168.1.51
192.168.1.52
```

- One IP address or hostname per line
- Comments start with `#`
- Empty lines are ignored

---

## Scripts Overview

### System Updates

#### update_and_remove_all.sh
**Purpose**: Update all systems and remove old kernels

**What it does**:
1. Connects to each host via SSH
2. Runs `apt update` to refresh package lists
3. Runs `apt upgrade -y` to install updates
4. Runs `apt autoremove -y` to remove unused packages and old kernels
5. Runs `apt autoclean` to clear package cache

**Why**: Centralized system maintenance ensures all devices stay updated, secure, and don't waste disk space on old kernel versions.

**Usage**:
```bash
chmod +x update_and_remove_all.sh
./update_and_remove_all.sh
```

**Output**: Shows SUCCESS or FAILED for each host.

---

### System Maintenance

#### update_all.sh
**Purpose**: Update, upgrade, and clean up all systems

**What it does**:
1. Connects to each host via SSH
2. Runs `apt update` to refresh package lists
3. Runs `apt upgrade -y` to install updates
4. Runs `apt autoremove -y` to remove unused packages
5. Runs `apt autoclean` to clear package cache

**Why**: Centralized system maintenance ensures all devices stay updated and secure without manual intervention on each machine.

**Usage**:
```bash
chmod +x update_all.sh
./update_all.sh
```

**Output**: Shows SUCCESS or FAILED for each host.

---

#### disable_auto_updates.sh
**Purpose**: Disable all automatic updates on all systems

**What it does**:
1. Stops and disables `unattended-upgrades` service
2. Stops and disables all `apt-daily` timers and services
3. Configures APT to disable automatic update checks
4. Disables automatic downloads and installations
5. Disables automatic reboots
6. Kills running update notifiers

**Why**: Gives you complete control over when updates occur. Automatic updates can:
- Interrupt work
- Consume bandwidth
- Cause unexpected reboots
- Break functionality if not tested

**Usage**:
```bash
chmod +x disable_auto_updates.sh
./disable_auto_updates.sh
```

**Configuration files modified**:
- `/etc/apt/apt.conf.d/20auto-upgrades`
- `/etc/apt/apt.conf.d/50unattended-upgrades`

---

#### reboot.sh
**Purpose**: Reboot all systems simultaneously

**What it does**:
1. Sends reboot command to each host
2. Systems reboot immediately

**Why**: Quickly restart all systems after updates or configuration changes.

**Usage**:
```bash
chmod +x reboot.sh
./reboot.sh
```

**Note**: SSH connections will drop as devices reboot. All show "Reboot command sent" status.

---

### Network Management

#### check_hosts.sh
**Purpose**: Quickly check which hosts are online or offline

**What it does**:
1. Pings each host from hosts.txt with 1-second timeout
2. Reports online/offline status for each
3. Saves results to timestamped file
4. Shows summary statistics (total, online, offline)

**Why**:
- Quick health check of entire fleet
- Identify offline systems before running other scripts
- Document system availability
- Troubleshoot network connectivity

**Usage**:
```bash
chmod +x check_hosts.sh
./check_hosts.sh
```

**Output file**: `host_status_YYYYMMDD_HHMMSS.txt`

**Example output**:
```
✓ 192.168.1.50 - ONLINE
✗ 192.168.1.51 - OFFLINE
✓ 192.168.1.52 - ONLINE

Summary:
  Total hosts: 3
  Online: 2
  Offline: 1
```

---

### Network Configuration

#### change_dns.sh
**Purpose**: Configure DNS servers on all systems

**What it does**:
1. Detects active ethernet connection (works with any connection name)
2. Sets DNS servers to:
   - Primary: `1.1.1.1` (Cloudflare - fastest, privacy-focused)
   - Secondary: `8.8.8.8` (Google - reliable, AWS connectivity)
   - Tertiary: `205.251.242.103` (AWS Route 53 - AWS optimized)
3. Ignores DHCP-assigned DNS
4. Restarts connection to apply changes

**Why**: Ensures consistent, fast, and reliable DNS across all systems. Prevents DNS issues from DHCP servers and improves privacy and performance.

**Usage**:
```bash
chmod +x change_dns.sh
./change_dns.sh
```

**Technical details**: Uses NetworkManager (`nmcli`) to modify connection settings.

---

#### fix_static_ip.sh
**Purpose**: Convert network connections from DHCP to static/manual IP

**What it does**:
1. Detects active ethernet connection
2. Reads current IP address (already configured)
3. Reads current gateway
4. Reads network prefix (subnet mask)
5. Changes connection method from DHCP to **manual/static**
6. Preserves the existing IP address
7. Sets DNS servers
8. Restarts connection to apply changes

**Why**: Fixes misconfigured systems that have static IPs but are set to DHCP mode. This was caused by an old installation error. Static IP configuration:
- Prevents IP address changes
- Ensures consistent network identity
- Required for many network services
- More reliable than DHCP

**Usage**:
```bash
chmod +x fix_static_ip.sh
./fix_static_ip.sh
```

**Important**: This does NOT change IP addresses - it only changes the configuration method from DHCP to static while keeping the same IPs.

---

#### require_sudo_network.sh
**Purpose**: Require administrator password for network settings changes

**What it does**:
1. Creates PolicyKit rules requiring authentication for NetworkManager
2. Restricts network settings modifications
3. Applies to all network GUI tools (nm-applet, network manager)
4. Restarts PolicyKit to apply changes immediately

**Why**: Security measure to prevent users from:
- Changing network settings
- Modifying connections
- Changing DNS settings
- Bypassing network policies

**Usage**:
```bash
chmod +x require_sudo_network.sh
./require_sudo_network.sh
```

**Configuration files created**:
- `/etc/polkit-1/localauthority/50-local.d/require-auth-network.pkla`
- `/etc/polkit-1/localauthority/50-local.d/restrict-network-manager.pkla`

---

### Desktop Customization

#### install_hostname_display.sh
**Purpose**: Display hostname in bottom-right corner of desktop

**What it does**:
1. Installs `conky` (system monitor tool)
2. Creates conky configuration for hostname display
3. Configures display properties:
   - Location: Bottom-right corner
   - Font: DejaVu Sans Mono, size 16
   - Style: Bold, uppercase, semi-transparent background
   - Updates every 60 seconds
4. Creates autostart entry for all users
5. Starts display immediately for logged-in users

**Why**: Easy visual identification of which computer you're working on. Essential in environments with many similar-looking systems.

**Usage**:
```bash
chmod +x install_hostname_display.sh
./install_hostname_display.sh
```

**Persistence**: Automatically starts on login for all users.

**Configuration files**:
- `~/.config/conky/hostname.conf` - Display configuration
- `~/.config/autostart/hostname-conky.desktop` - Autostart entry

---

#### set_wallpaper.sh
**Purpose**: Set random desktop wallpaper on all systems

**What it does**:
1. Reads wallpaper URLs from `wallpapers.txt`
2. Randomly selects ONE wallpaper
3. Downloads it to each host
4. Sets it as desktop background for all logged-in users
5. Applies to all monitor types (eDP, VGA, HDMI, DisplayPort)
6. Forces desktop refresh to show changes immediately

**Why**:
- Centralized wallpaper management
- Consistent branding across all systems
- Easy to update wallpapers fleet-wide
- Random selection adds variety

**Usage**:
```bash
# Add wallpaper URLs to wallpapers.txt (one per line)
nano wallpapers.txt

chmod +x set_wallpaper.sh
./set_wallpaper.sh
```

**wallpapers.txt format**:
```
https://example.com/wallpaper1.jpg
https://example.com/wallpaper2.png
https://example.com/wallpaper3.jpg
```

**Technical details**: Uses XFCE's `xfconf-query` to set wallpaper and `xfdesktop --reload` to refresh.

---

### Application Management

#### install_firefox.sh
**Purpose**: Install Firefox and create desktop shortcut

**What it does**:
1. Updates package lists
2. Installs Firefox browser
3. Creates Firefox desktop icon for `sweetagent` user
4. Sets correct permissions
5. Marks icon as trusted (for newer Ubuntu versions)

**Why**: Ensures all systems have a standard web browser with desktop access.

**Usage**:
```bash
chmod +x install_firefox.sh
./install_firefox.sh
```

**Desktop icon location**: `/home/sweetagent/Desktop/firefox.desktop`

---

#### restrict_chromium_cpu.sh
**Purpose**: Limit CPU usage for Chromium and Slack

**What it does**:
1. Installs `cpulimit` tool
2. Creates background monitoring script
3. Limits Chromium processes to **50% CPU** each
4. Limits Slack processes to **25% CPU** each
5. Monitors every 10 seconds for new processes
6. Creates autostart entry for all users
7. Starts limiter immediately for logged-in users

**Why**: Prevents resource-intensive applications from consuming all CPU. Common issues:
- Chromium tabs consuming 100% CPU
- Slack eating resources in background
- System becoming unresponsive
- Other applications starved for CPU

**Usage**:
```bash
chmod +x restrict_chromium_cpu.sh
./restrict_chromium_cpu.sh
```

**How it works**: Uses `cpulimit` to monitor and throttle processes. Each Chromium/Slack process gets its own CPU limiter.

**Configuration**:
- Script: `~/.local/bin/chromium-cpu-limit.sh`
- Autostart: `~/.config/autostart/chromium-cpu-limit.desktop`

**Adjusting limits**: Edit the `-l` values in the script:
- `-l 50` = 50% CPU limit
- `-l 25` = 25% CPU limit

---

### System Monitoring

#### speedtest_all.sh
**Purpose**: Run network speed test on all systems and collect results

**What it does**:
1. Installs `speedtest-cli` if not present
2. Runs speed test on each host (one at a time)
3. Measures:
   - Ping (latency in ms)
   - Download speed (Mbit/s)
   - Upload speed (Mbit/s)
4. Saves results to timestamped text file
5. Displays all results at completion

**Why**:
- Monitor network performance across fleet
- Identify problematic connections
- Verify network infrastructure
- Document baseline performance
- Troubleshoot speed issues

**Usage**:
```bash
chmod +x speedtest_all.sh
./speedtest_all.sh
```

**Output file**: `speedtest_results_YYYYMMDD_HHMMSS.txt`

**Example output**:
```
--- 192.168.1.50 ---
Ping: 12.345 ms
Download: 95.43 Mbit/s
Upload: 45.67 Mbit/s

--- 192.168.1.51 ---
Ping: 15.234 ms
Download: 87.23 Mbit/s
Upload: 43.21 Mbit/s
```

---

#### cleanup_all.sh
**Purpose**: Clean up disk space on all systems by removing temporary files and caches

**What it does**:
1. Empties trash for sweetagent user
2. Cleans browser caches (Chromium and Firefox)
3. Removes thumbnail cache
4. Cleans temporary files in user directories
5. Removes old log files (older than 30 days)
6. Cleans APT package cache
7. Removes old/unused kernels
8. Cleans system /tmp directory (files older than 7 days)
9. Vacuums journal logs (keeps last 7 days)
10. Shows available disk space after cleanup

**Why**:
- Recover disk space on systems running low
- Remove accumulated cache files
- Clean up old log files
- Remove unused packages and kernels
- Improve system performance
- Maintain consistent disk usage across fleet

**Usage**:
```bash
chmod +x cleanup_all.sh
./cleanup_all.sh
```

**What gets cleaned**:
- `/home/sweetagent/.local/share/Trash/` - User trash
- `/home/sweetagent/.cache/chromium/` - Chromium cache
- `/home/sweetagent/.cache/mozilla/` - Firefox cache
- `/home/sweetagent/.cache/thumbnails/` - Thumbnail cache
- `/home/sweetagent/.cache/tmp/` - Temp cache files
- `/home/sweetagent/tmp/` - User temp files
- Log files older than 30 days
- APT cache and old packages
- Old kernel versions (keeps current + 1 previous)
- System journal logs older than 7 days

**Output**: Shows cleanup progress and final disk space for each host.

---

### Power Management

#### collect_mac_addresses.sh
**Purpose**: Collect MAC addresses from all systems for Wake-on-LAN

**What it does**:
1. Connects to each host
2. Detects active ethernet device
3. Retrieves MAC address from network interface
4. Collects hostname
5. Saves all information to timestamped file
6. Format: `IP | HOSTNAME | DEVICE | MAC`

**Why**:
- Required for Wake-on-LAN functionality
- Documents network hardware addresses
- Maps MAC addresses to hostnames and IPs
- Useful for network troubleshooting
- Creates inventory of network interfaces

**Usage**:
```bash
chmod +x collect_mac_addresses.sh
./collect_mac_addresses.sh
```

**Output file**: `mac_addresses_YYYYMMDD_HHMMSS.txt`

**Example output**:
```
192.168.1.50 | HOST01 | enp0s3 | AA:BB:CC:DD:EE:FF
192.168.1.51 | HOST02 | enp0s3 | 11:22:33:44:55:66
192.168.1.52 | HOST03 | enp0s3 | 77:88:99:AA:BB:CC
```

**Important**: Run this script BEFORE using `wol_all.sh` for the first time.

---

#### wol_all.sh
**Purpose**: Wake up all systems using Wake-on-LAN (WOL) with improved reliability

**What it does**:
1. Checks if `wakeonlan` tool is installed (installs if missing)
2. Finds most recent MAC address file from `collect_mac_addresses.sh`
3. Sends WOL magic packet **3 times per device** for reliability
4. Uses delays between packets (0.2s) and between devices (0.3s)
5. Shows progress counter ([1/50], [2/50], etc.)
6. Waits 10 seconds after sending all packets
7. **Auto-verifies** by pinging each device to check if online
8. Shows detailed summary of online/offline devices

**Why**:
- Power on all systems remotely without physical access
- **3x packet retry** - Much more reliable than single packet
- **Auto-verification** - Know immediately which systems came online
- Save energy by powering down when not needed
- Quick fleet-wide boot from central location
- No need to walk to each computer
- Useful after power outages or maintenance

**Usage**:
```bash
# First time: Collect MAC addresses
./collect_mac_addresses.sh

# Then wake up all systems
chmod +x wol_all.sh
./wol_all.sh
```

**Example output**:
```
Found 50 devices with MAC addresses

[1/50] Waking up: 192.168.1.50 (HOST01) - MAC: AA:BB:CC:DD:EE:FF
  ✓ WOL packets sent successfully (3x)
[2/50] Waking up: 192.168.1.51 (HOST02) - MAC: 11:22:33:44:55:66
  ✓ WOL packets sent successfully (3x)

Waiting 10 seconds before checking status...

=== Checking which devices are now online ===
  ✓ 192.168.1.50 (HOST01) - ONLINE
  ✓ 192.168.1.51 (HOST02) - ONLINE

Summary:
Online: 48/50
Offline: 2/50
```

**Requirements**:
- Computers must be connected to power
- Network switches must remain powered on
- BIOS/UEFI Wake-on-LAN must be enabled
- Network cards must support WOL
- MAC addresses must be collected first

**Note**: Systems typically take 30-60 seconds to fully boot after WOL packet is sent.

**Troubleshooting WOL**:
If systems don't wake up:
1. Verify BIOS has Wake-on-LAN enabled
2. Check network cable is connected
3. Ensure power is connected (not just battery)
4. Verify MAC address is correct
5. Check if network card supports WOL: `ethtool <device> | grep Wake-on`
6. Enable WOL on interface: `sudo ethtool -s <device> wol g`
7. Some network switches block WOL packets - check switch settings

---

### Hardware Information

#### collect_hardware_info.sh
**Purpose**: Collect comprehensive hardware information from all systems

**What it does**:
1. Connects to each host via SSH
2. Uses `dmidecode` to read BIOS/UEFI hardware information
3. Collects:
   - System manufacturer (Dell, HP, Lenovo, etc.)
   - Model/Product name (OptiPlex 7050, EliteDesk 800, etc.)
   - Serial number (for warranty tracking)
   - BIOS version
   - CPU model and specifications
   - Total RAM (in GB)
   - Total disk size (in GB)
4. Saves all information to timestamped file
5. Displays formatted report

**Why**:
- Hardware inventory management
- Asset tracking and documentation
- Warranty tracking using serial numbers
- Planning hardware upgrades
- Identifying system specifications
- License management
- Support ticket creation

**Usage**:
```bash
chmod +x collect_hardware_info.sh
./collect_hardware_info.sh
```

**Output file**: `hardware_info_YYYYMMDD_HHMMSS.txt`

**Example output**:
```
--- 192.168.1.50 (HOST01) ---
  Manufacturer: Dell Inc.
  Model: OptiPlex 7050
  Serial Number: 1A2B3C4
  BIOS Version: 1.21.0
  CPU: Intel(R) Core(TM) i5-7500 CPU @ 3.40GHz
  RAM: 8.00 GB
  Disk Size: 256.00 GB

--- 192.168.1.51 (HOST02) ---
  Manufacturer: HP
  Model: EliteDesk 800 G3
  Serial Number: 5D6E7F8
  BIOS Version: P21 Ver. 02.39
  CPU: Intel(R) Core(TM) i7-7700 CPU @ 3.60GHz
  RAM: 16.00 GB
  Disk Size: 512.00 GB
```

**Technical details**: Uses `dmidecode` which reads hardware info directly from BIOS/UEFI. Works on physical machines and most virtual machines.

---

#### collect_ram_info.sh
**Purpose**: Collect detailed RAM usage and availability information

**What it does**:
1. Connects to each host
2. Reads `/proc/meminfo` for memory statistics
3. Calculates:
   - Total RAM in GB and MB
   - Available RAM in GB
   - Used RAM percentage
4. Saves detailed results to timestamped file
5. Calculates fleet-wide statistics:
   - Total RAM across all systems
   - Average RAM per system
   - Total systems counted

**Why**:
- Monitor memory usage across fleet
- Identify systems with low memory
- Plan memory upgrades
- Capacity planning
- Performance troubleshooting
- Document system resources

**Usage**:
```bash
chmod +x collect_ram_info.sh
./collect_ram_info.sh
```

**Output file**: `ram_info_YYYYMMDD_HHMMSS.txt`

**Example output**:
```
192.168.1.50 | HOST01 | 8.00 GB (8192 MB) | Available: 3.25 GB | Used: 59.4%
192.168.1.51 | HOST02 | 16.00 GB (16384 MB) | Available: 8.12 GB | Used: 49.3%
192.168.1.52 | HOST03 | 4.00 GB (4096 MB) | Available: 0.85 GB | Used: 78.8%

=== Statistics ===
Total systems: 3
Combined RAM across all systems: 28.00 GB
Average RAM per system: 9.33 GB
```

**Alerts**: Systems with >80% used RAM may need attention or upgrades.

---

### Utilities

#### run_remote_command.sh
**Purpose**: Execute any custom command on all hosts interactively

**What it does**:
1. Prompts you to enter a command
2. Shows what will be executed and asks for confirmation
3. Runs the command on each host via SSH
4. Collects output from each system
5. Saves detailed results to timestamped file
6. Shows success/failure summary

**Why**:
- Run one-off commands without writing new scripts
- Quick troubleshooting across fleet
- Emergency fixes or changes
- Custom maintenance tasks
- Ad-hoc information gathering
- Testing commands before scripting

**Usage**:
```bash
chmod +x run_remote_command.sh
./run_remote_command.sh

# Examples of commands you might run:
# - df -h
# - uptime
# - systemctl status nginx
# - ps aux | grep chromium
# - cat /etc/os-release
```

**Output file**: `remote_command_YYYYMMDD_HHMMSS.txt`

**Example session**:
```
Enter the command you want to run on all hosts:
Command: df -h /

You are about to run the following command on all hosts:
  df -h /

Are you sure? (yes/no): yes

Processing 192.168.1.50...
  ✓ SUCCESS
Processing 192.168.1.51...
  ✓ SUCCESS

Summary:
  Total hosts: 2
  Success: 2
  Failed: 0
```

**Safety**:
- Shows command before execution
- Requires "yes" confirmation
- Saves output for review
- Can run any command (use with caution!)

**Important**: This tool runs commands with sudo privileges. Double-check commands before confirming!

---

### Security & Access Control

All scripts use the following security model:

**Authentication**:
- SSH user: `sweetagent`
- SSH password: `sweetcom`
- Sudo password: `sweetcom`

**SSH Options**:
- `StrictHostKeyChecking=no` - Auto-accept host keys
- `ConnectTimeout=10` - 10-second connection timeout

**Security Considerations**:
1. **Hardcoded credentials**: Scripts contain passwords in plaintext
   - Store scripts in secure location
   - Set script permissions: `chmod 700 *.sh`
   - Restrict directory access: `chmod 700 /remote_tools`

2. **Network security**:
   - Run from trusted network only
   - Consider VPN for remote access
   - Firewall SSH access to management server only

3. **Sudo access**:
   - `sweetagent` user has sudo privileges
   - Required for system modifications
   - Consider sudoers restrictions for production

---

## Common Patterns

### Script Structure
All scripts follow this pattern:

```bash
#!/bin/bash
set +e  # Continue on errors

for host in $(cat hosts.txt)
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh [options] sweetagent@"$host" '
        # Remote commands here
    ' || true

    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done
echo "All hosts processed."
```

### Why This Design?

**Loop continuation**: Scripts use `|| true` and `set +e` to ensure:
- One failed host doesn't stop the entire run
- All hosts are processed regardless of failures
- Clear SUCCESS/FAILED status for each host

**Sequential processing**: Hosts are processed one at a time:
- Easier to debug issues
- Clear progress indication
- Prevents overwhelming network
- Some operations require it (like speedtest)

**Error handling**: Each host's success/failure is tracked:
- Easy to identify problematic systems
- Rerun script only processes all hosts
- Clear audit trail

---

## Troubleshooting

### Script stops after first host
- Check for missing `|| true` after SSH command
- Verify `set +e` at script start
- Ensure loop syntax is correct

### SSH connection fails
- Verify host is reachable: `ping 192.168.1.50`
- Check SSH service: `ssh sweetagent@192.168.1.50`
- Verify credentials
- Check firewall rules

### Permission denied
- Verify sudo password is correct
- Check `sweetagent` user has sudo access
- Verify script has execute permission: `chmod +x script.sh`

### Network changes don't persist
- Check NetworkManager is running
- Verify connection profile exists
- Review system logs: `journalctl -xe`

### Autostart doesn't work
- Check `.desktop` file syntax
- Verify file permissions
- Check autostart directory exists
- Review session logs

---

## Maintenance

### Regular Tasks

**Weekly**:
- Run `update_all.sh` to update all systems
- Review output for failed hosts

**Monthly**:
- Run `speedtest_all.sh` to monitor network performance
- Review and clean up old speedtest results
- Verify autostart configurations are working

**As Needed**:
- Update `wallpapers.txt` with new wallpaper URLs
- Run `fix_static_ip.sh` after network changes
- Adjust CPU limits if performance issues occur

### Updating Scripts

When modifying scripts:
1. Test on a single host first
2. Verify changes don't break loop continuation
3. Update this documentation
4. Backup working versions

### Adding New Hosts

1. Add IP to `hosts.txt`
2. Verify SSH access works
3. Run essential scripts:
   - `update_all.sh`
   - `fix_static_ip.sh`
   - `change_dns.sh`
   - `disable_auto_updates.sh`

---

## Best Practices

### Running Scripts

1. **Always review output**: Check for FAILED hosts
2. **Run updates regularly**: Keep systems secure
3. **Test changes**: Use one host first when possible
4. **Document changes**: Update this file when modifying scripts
5. **Backup configurations**: Keep copies of working scripts

### Security

1. **Protect script directory**: `chmod 700` on directory
2. **Secure hosts.txt**: Contains network topology
3. **Rotate credentials**: Change passwords periodically
4. **Audit access**: Review who can run scripts
5. **Network isolation**: Run from management network

### Performance

1. **Off-peak updates**: Run `update_all.sh` during low-usage times
2. **Batch operations**: Group related scripts together
3. **Monitor bandwidth**: Large updates affect network
4. **Stagger reboots**: Consider manual reboots if timing matters

---

## File Summary

| File | Purpose | Category | Frequency |
|------|---------|----------|-----------|
| **Menu & Configuration** | | | |
| `menu.sh` | Interactive menu system | Utility | Daily |
| `hosts.txt` | List of managed systems | Config | Static |
| `wallpapers.txt` | Wallpaper URL list | Config | Update as needed |
| **System Updates** | | | |
| `update_all.sh` | System updates (apt) | Updates | Weekly |
| `update_and_remove_all.sh` | Updates + remove old kernels | Updates | Weekly |
| `disable_auto_updates.sh` | Disable auto-updates | Updates | Once per system |
| **System Maintenance** | | | |
| `cleanup_all.sh` | Clean up disk space | Maintenance | Monthly |
| `reboot.sh` | Reboot all systems | Maintenance | As needed |
| **Network Management** | | | |
| `check_hosts.sh` | Check online/offline status | Network | As needed |
| `wol_all.sh` | Wake-on-LAN (3x retry + verify) | Network | Daily or as needed |
| `collect_mac_addresses.sh` | Collect MAC addresses | Network | Once or when hardware changes |
| `change_dns.sh` | Configure DNS servers | Network | Once or when needed |
| `fix_static_ip.sh` | Fix DHCP→Static IP | Network | Once per system |
| `require_sudo_network.sh` | Lock network settings | Network | Once per system |
| `speedtest_all.sh` | Test internet speeds | Network | Monthly |
| **Hardware Information** | | | |
| `collect_hardware_info.sh` | Get manufacturer, model, specs | Hardware | Quarterly or as needed |
| `collect_ram_info.sh` | Collect RAM information | Hardware | Monthly or as needed |
| **Software Installation** | | | |
| `install_firefox.sh` | Install Firefox browser | Software | Once per system |
| `install_hostname_display.sh` | Show hostname on desktop | Software | Once per system |
| **System Configuration** | | | |
| `set_wallpaper.sh` | Set random wallpaper | Config | As desired |
| `restrict_chromium_cpu.sh` | Limit Chromium CPU to 50% | Config | Once per system |
| **Utilities** | | | |
| `run_remote_command.sh` | Execute custom commands | Utility | As needed |

---

## Quick Start Guide

### Interactive Menu (Recommended)

The easiest way to use these scripts is through the interactive menu:

```bash
cd "/path/to/scripts"
chmod +x menu.sh
./menu.sh
```

The menu provides:
- Organized access to all 21 scripts
- Clear descriptions of what each script does
- No need to remember script names
- Built-in error checking

### Initial Setup

1. **Prepare server**:
```bash
sudo apt install sshpass
cd "/Users/axelloosme/Desktop/SCRIPTS/auto update and remove"
chmod +x *.sh
```

2. **Create hosts.txt**:
```bash
nano hosts.txt
# Add your IPs, one per line
```

3. **Run essential scripts** (via menu or directly):
```bash
# Using the menu (recommended)
./menu.sh
# Then select: 3, 10, 9, 1, 16, 18, 8

# Or run directly:
./disable_auto_updates.sh     # Take control of updates
./fix_static_ip.sh            # Ensure static IPs
./change_dns.sh               # Set DNS servers
./update_and_remove_all.sh    # Update all systems
./install_hostname_display.sh # Show hostnames
./restrict_chromium_cpu.sh    # Limit CPU usage
./collect_mac_addresses.sh    # Collect MACs for WOL
```

### Daily Usage

**Using the menu**:
```bash
./menu.sh
# Select the script you need by number
```

**Common tasks**:
- Check which systems are online: Option 6
- Wake up all computers: Option 7
- Update all systems: Option 1 or 2
- Run custom command: Option 19

### Regular Maintenance

**Weekly**:
```bash
./menu.sh
# Select option 1 or 2: Update systems

# Or directly:
./update_and_remove_all.sh
```

**After updates if needed**:
```bash
./menu.sh
# Select option 5: Reboot

# Or directly:
./reboot.sh
```

**Monthly**:
```bash
./menu.sh
# Select option 4: Cleanup
# Select option 12: Speed test
# Select option 13-14: Hardware inventory

# Or directly:
./cleanup_all.sh
./speedtest_all.sh
./collect_hardware_info.sh
```

---

## License & Support

This is a custom internal tool for managing Xubuntu systems. Modify and use as needed for your environment.

For issues or questions, refer to this documentation or review the script source code directly.

---

## Version History

- **v2.0** - Interactive Menu & Enhanced Features
  - Added `menu.sh` - Interactive menu system with 21 scripts
  - Added `check_hosts.sh` - Check online/offline status
  - Added `run_remote_command.sh` - Execute custom commands
  - Added `collect_hardware_info.sh` - Manufacturer, model, specs
  - Added `collect_ram_info.sh` - Detailed RAM information
  - Enhanced `wol_all.sh` - 3x packet retry + auto-verification
  - Reorganized all scripts into 6 logical categories
  - Complete documentation update

- **v1.0** - Initial documentation
  - All core management scripts
  - Network configuration
  - Desktop customization
  - Application management
  - System monitoring
