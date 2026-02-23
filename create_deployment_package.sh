#!/bin/bash

# Script to create a deployment package with all scripts
# This creates a tar.gz archive that can be transferred to another server

PACKAGE_NAME="xubuntu-remote-management-$(date +%Y%m%d_%H%M%S).tar.gz"
TEMP_DIR="xubuntu-remote-management"

echo "=== Creating Deployment Package ==="
echo ""

# Create temporary directory
mkdir -p "$TEMP_DIR"

# Copy all shell scripts
echo "Copying scripts..."
cp *.sh "$TEMP_DIR/" 2>/dev/null || true

# Create hosts.txt template if it doesn't exist in temp
if [ ! -f "$TEMP_DIR/hosts.txt" ]; then
    cat > "$TEMP_DIR/hosts.txt" << 'EOF'
# Add your Xubuntu host IPs here, one per line
# Example:
# 192.168.1.50
# 192.168.1.51
# 192.168.1.52
EOF
fi

# Create wallpapers.txt template if it doesn't exist in temp
if [ ! -f "$TEMP_DIR/wallpapers.txt" ]; then
    cat > "$TEMP_DIR/wallpapers.txt" << 'EOF'
# Add wallpaper URLs here, one per line
# Example:
# https://example.com/wallpaper1.jpg
# https://example.com/wallpaper2.png
EOF
fi

# Copy README if it exists
if [ -f "README.md" ]; then
    cp README.md "$TEMP_DIR/"
    echo "✓ Copied README.md"
fi

# Create installation instructions
cat > "$TEMP_DIR/INSTALL.txt" << 'EOF'
=== Installation Instructions ===

1. Extract this archive on your Debian server:
   tar -xzf xubuntu-remote-management-*.tar.gz
   cd xubuntu-remote-management

2. Install required packages:
   sudo apt install sshpass wakeonlan

3. Make all scripts executable:
   chmod +x *.sh

4. Edit hosts.txt and add your Xubuntu device IPs (one per line):
   nano hosts.txt

5. (Optional) Add wallpaper URLs to wallpapers.txt:
   nano wallpapers.txt

6. Run the interactive menu:
   ./menu.sh

   Or run scripts directly:
   ./update_all.sh
   ./check_hosts.sh
   ./wol_all.sh
   etc.

=== Script Categories ===

System Updates:
  - update_all.sh
  - update_and_remove_all.sh
  - disable_auto_updates.sh

System Maintenance:
  - cleanup_all.sh
  - reboot.sh

Network Management:
  - check_hosts.sh
  - wol_all.sh
  - collect_mac_addresses.sh
  - change_dns.sh
  - fix_static_ip.sh
  - require_sudo_network.sh
  - speedtest_all.sh

Hardware Information:
  - collect_hardware_info.sh
  - collect_ram_info.sh

Software Installation:
  - install_firefox.sh
  - install_hostname_display.sh

System Configuration:
  - set_wallpaper.sh
  - restrict_chromium_cpu.sh

Utilities:
  - run_remote_command.sh
  - menu.sh (Interactive menu - RECOMMENDED)

=== Quick Start ===

1. Start with the menu for easiest use:
   ./menu.sh

2. Initial setup (recommended order):
   - Option 3: Disable auto-updates
   - Option 10: Fix static IP
   - Option 9: Change DNS
   - Option 2: Update all systems
   - Option 16: Install hostname display
   - Option 18: Restrict CPU usage
   - Option 8: Collect MAC addresses (for Wake-on-LAN)

3. Regular maintenance:
   - Weekly: Option 1 or 2 (Update systems)
   - Monthly: Option 4 (Cleanup), Option 12 (Speed test)
   - As needed: Option 6 (Check hosts), Option 7 (Wake-on-LAN)

=== Support ===

All scripts use:
  - SSH User: sweetagent
  - SSH Password: sweetcom
  - Sudo Password: sweetcom

For detailed documentation, see README.md

EOF

# Count scripts
SCRIPT_COUNT=$(ls -1 "$TEMP_DIR"/*.sh 2>/dev/null | wc -l)

echo "✓ Copied $SCRIPT_COUNT scripts"
echo "✓ Created installation instructions"

# Create the tar.gz archive
tar -czf "$PACKAGE_NAME" "$TEMP_DIR"

# Clean up temp directory
rm -rf "$TEMP_DIR"

# Get file size
PACKAGE_SIZE=$(du -h "$PACKAGE_NAME" | cut -f1)

echo ""
echo "=== Package Created Successfully! ==="
echo ""
echo "Package: $PACKAGE_NAME"
echo "Size: $PACKAGE_SIZE"
echo "Scripts included: $SCRIPT_COUNT"
echo ""
echo "To deploy on another server:"
echo "  1. Copy $PACKAGE_NAME to the target server"
echo "  2. Extract: tar -xzf $PACKAGE_NAME"
echo "  3. Follow instructions in INSTALL.txt"
echo ""
echo "Quick deploy command:"
echo "  scp $PACKAGE_NAME user@server:/path/to/destination/"
echo ""
EOF
chmod +x create_deployment_package.sh
echo "✓ Created create_deployment_package.sh"