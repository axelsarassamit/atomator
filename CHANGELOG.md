# Atomator - Changelog

## v.01.00.00
- Initial complete rewrite
- 34 scripts with version system
- Update mechanism

## v.02.00.00
- Submenu system (8 categories)
- Report viewers for all data collectors
- GitHub update support
- Delete SSH keys now local-only
- Timestamped output files

## v.02.01.00
- Renamed to "Atomator"
- New version format v.XX.YY.AA
- Credentials system (credentials.conf) - no more hardcoded passwords
- Password change script for remote hosts
- Debug menu logging (max 10MB)
- Update catalog with version revert
- Watchdog host configuration (hidden 666 menu)
- View README from menu
- Fixed: sudo command not found in update menu

## v.02.01.01
- Fixed: VPN removal script wiped DNS causing total network loss on all hosts
- Fixed: Static IP script now always sets DNS (fallback to 1.1.1.1/8.8.8.8/9.9.9.9)

## v.02.02.00
- Standardized all 6 report files to consistent TSV (tab-separated) format
- All reports now have: header (Report/Date/Hosts), column headers, one row per host
- Easy to copy-paste into spreadsheets (Excel, Google Sheets)
- OFFLINE hosts now always get a row (no missing data)
- Summary line at bottom of every report
- Added Used column to disk space report
- Services report now one flat row per host (not multi-line)
- Speed test results parsed into Ping/Download/Upload columns

## v.02.02.01
- Custom DNS option in fix_static_ip.sh (keep current / Cloudflare+Google+Quad9 / custom)
- Custom DNS option in change_dns.sh (Cloudflare+Google+Quad9 / custom)
- Updated menu text and README descriptions to reflect custom DNS options

## v.02.03.00
- fix_static_ip.sh now derives IP from gateway + hostname digits
- IP = gateway first 3 octets + last digits of computer name (e.g. BKSAL058 = .58)
- Subnet mask /24, validates hostname has trailing digits and octet <= 254

## v.02.03.01
- Update screen now shows changelog from the NEW version instead of the old one

## v.02.03.02
- Changelog now shows oldest first, newest last (latest changes visible at bottom)

## v.02.03.03
- check_hosts.sh now shows hostname for online hosts via SSH

## v.02.04.00
- Added install_simplenote.sh (snap-based note-taking app)
- Added install_redshift.sh (screen color temperature with autostart)

## v.02.04.01
- Fixed GitHub update: use API endpoint instead of raw CDN to avoid cache delay

## v.02.05.00
- Added fix_slow_sudo.sh - adds hostname to /etc/hosts to fix slow sudo on all hosts

## v.02.05.01
- Added fix_hostname_display.sh - repairs conky hostname display (kills stuck processes, recreates config, restarts immediately)

## v.02.06.00
- Added remove_simplenote.sh and remove_redshift.sh
- Added install/remove for Google Chrome, Chromium, and Xpad (sticky notes)
- Software menu expanded to 16 options

## v.02.06.01
- Improved fix_slow_sudo.sh: fixes 127.0.1.1 line, nsswitch.conf order, verifies hostname resolution

## v.02.06.02
- Fixed fix_hostname_display.sh hanging: conky now fully detached with nohup so SSH session doesn't get stuck

## v.02.07.00
- Redesigned all menus with section dividers and spacing for better readability
- Software menu grouped into Install, Remove, and Fix sections
- Network menu grouped into Status & Wake, DNS & IP, and Security & Testing
- Information menu grouped by category (Hardware, Memory, Disk, Uptime, Services)
- Updates menu split into Updates and Maintenance sections
- Tools menu split into Remote and Fix sections
- Added descriptions to all menu items that were missing them

## v.02.07.01
- Fixed duplicate hostname display: now removes ALL old conky configs and autostart files before recreating
- Fixed black background: removed ARGB transparency (fails without compositor), uses pseudo-transparency instead
- Removed text shadow that caused dark appearance
- Both install and fix scripts updated with same clean config

## v.02.07.02
- Hostname display: added black outline on white text for better readability
- Moved closer to taskbar (gap_y 26) to match desired position
