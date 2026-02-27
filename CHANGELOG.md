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
