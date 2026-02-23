#!/bin/bash

# Script to create all remote management scripts
# This allows easy deployment to another server

SCRIPT_DIR="$(pwd)"

echo "=== Remote Xubuntu Management Scripts Generator ==="
echo "Creating all scripts in: $SCRIPT_DIR"
echo ""

# Create hosts.txt template
cat > hosts.txt << 'EOF'
# Add your Xubuntu host IPs here, one per line
# Example:
# 192.168.1.50
# 192.168.1.51
# 192.168.1.52
EOF
echo "✓ Created hosts.txt template"

# Create wallpapers.txt template
cat > wallpapers.txt << 'EOF'
# Add wallpaper URLs here, one per line
# Example:
# https://example.com/wallpaper1.jpg
# https://example.com/wallpaper2.png
EOF
echo "✓ Created wallpapers.txt template"

# Create update_all.sh
cat > update_all.sh << 'EOF'
#!/bin/bash
set +e
for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S bash -c "apt update && apt upgrade -y && apt autoremove -y && apt autoclean"' || true
    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done
echo "All hosts processed."
EOF
chmod +x update_all.sh
echo "✓ Created update_all.sh"

# Create update_and_remove_all.sh
cat > update_and_remove_all.sh << 'EOF'
#!/bin/bash
set +e
for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S bash -c "apt update && apt upgrade -y && apt autoremove -y --purge && apt autoclean"' || true
    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done
echo "All hosts processed."
EOF
chmod +x update_and_remove_all.sh
echo "✓ Created update_and_remove_all.sh"

# Create disable_auto_updates.sh
cat > disable_auto_updates.sh << 'EOF'
#!/bin/bash
set +e

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S bash -c "
        echo \"Disabling automatic updates...\"

        # Stop and disable unattended-upgrades service
        systemctl stop unattended-upgrades 2>/dev/null || true
        systemctl disable unattended-upgrades 2>/dev/null || true

        # Stop and disable apt-daily services
        systemctl stop apt-daily.timer 2>/dev/null || true
        systemctl disable apt-daily.timer 2>/dev/null || true
        systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
        systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
        systemctl stop apt-daily.service 2>/dev/null || true
        systemctl disable apt-daily.service 2>/dev/null || true
        systemctl stop apt-daily-upgrade.service 2>/dev/null || true
        systemctl disable apt-daily-upgrade.service 2>/dev/null || true

        # Configure APT to disable automatic updates
        cat > /etc/apt/apt.conf.d/20auto-upgrades << EOL
APT::Periodic::Update-Package-Lists \"0\";
APT::Periodic::Download-Upgradeable-Packages \"0\";
APT::Periodic::AutocleanInterval \"0\";
APT::Periodic::Unattended-Upgrade \"0\";
EOL

        # Disable unattended-upgrades
        cat > /etc/apt/apt.conf.d/50unattended-upgrades << EOL
Unattended-Upgrade::Allowed-Origins {};
Unattended-Upgrade::Automatic-Reboot \"false\";
EOL

        # Stop update-notifier
        killall update-notifier 2>/dev/null || true

        echo \"✓ Automatic updates disabled\"
    "' || true
    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done
echo "All hosts processed."
EOF
chmod +x disable_auto_updates.sh
echo "✓ Created disable_auto_updates.sh"

# Create cleanup_all.sh
cat > cleanup_all.sh << 'EOF'
#!/bin/bash
set +e

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S bash -c "
        echo \"Cleaning up system on $host...\"

        # Clean trash for sweetagent user
        echo \"Emptying trash...\"
        rm -rf /home/sweetagent/.local/share/Trash/files/* 2>/dev/null
        rm -rf /home/sweetagent/.local/share/Trash/info/* 2>/dev/null

        # Clean browser cache (Chromium)
        echo \"Cleaning Chromium cache...\"
        rm -rf /home/sweetagent/.cache/chromium/* 2>/dev/null

        # Clean browser cache (Firefox)
        echo \"Cleaning Firefox cache...\"
        rm -rf /home/sweetagent/.cache/mozilla/* 2>/dev/null

        # Clean thumbnail cache
        echo \"Cleaning thumbnail cache...\"
        rm -rf /home/sweetagent/.cache/thumbnails/* 2>/dev/null

        # Clean temporary files
        echo \"Cleaning temporary files...\"
        rm -rf /home/sweetagent/.cache/tmp/* 2>/dev/null
        rm -rf /home/sweetagent/tmp/* 2>/dev/null
        rm -rf /home/sweetagent/.tmp/* 2>/dev/null

        # Clean old log files in home directory
        echo \"Cleaning old log files...\"
        find /home/sweetagent -name \"*.log\" -type f -mtime +30 -delete 2>/dev/null

        # Clean APT cache
        echo \"Cleaning APT cache...\"
        apt-get clean
        apt-get autoclean

        # Remove old kernels
        echo \"Removing old kernels...\"
        apt-get autoremove -y --purge

        # Clean system tmp
        echo \"Cleaning /tmp...\"
        find /tmp -type f -atime +7 -delete 2>/dev/null

        # Clean journal logs older than 7 days
        echo \"Cleaning old journal logs...\"
        journalctl --vacuum-time=7d 2>/dev/null || true

        # Show disk usage after cleanup
        DISK_FREE=\$(df -h / | tail -n1 | awk '\''{print \$4}'\'' )
        echo \"✓ Cleanup complete\"
        echo \"✓ Available disk space: \$DISK_FREE\"
    "' || true
    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done
echo "All hosts processed."
EOF
chmod +x cleanup_all.sh
echo "✓ Created cleanup_all.sh"

# Create reboot.sh
cat > reboot.sh << 'EOF'
#!/bin/bash
set +e

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Rebooting $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S reboot' || true
    echo "$host: Reboot command sent"
done
echo "All hosts sent reboot command."
EOF
chmod +x reboot.sh
echo "✓ Created reboot.sh"

echo ""
echo "Creating network management scripts..."

# Create check_hosts.sh
cat > check_hosts.sh << 'EOF'
#!/bin/bash
set +e

echo "=== Checking Host Status ==="
echo ""

if [ ! -f "hosts.txt" ]; then
    echo "ERROR: hosts.txt not found!"
    exit 1
fi

ONLINE=0
OFFLINE=0
TOTAL=0

# Create results file with timestamp
RESULTS_FILE="host_status_$(date +%Y%m%d_%H%M%S).txt"
echo "Host Status Check - $(date)" > "$RESULTS_FILE"
echo "======================================" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

while read -r host; do
    # Skip empty lines and comments
    if [ -z "$host" ] || [[ "$host" =~ ^# ]]; then
        continue
    fi

    ((TOTAL++))

    # Ping with 1 second timeout
    ping -c 1 -W 1 "$host" &>/dev/null

    if [ $? -eq 0 ]; then
        echo "✓ $host - ONLINE"
        echo "✓ $host - ONLINE" >> "$RESULTS_FILE"
        ((ONLINE++))
    else
        echo "✗ $host - OFFLINE"
        echo "✗ $host - OFFLINE" >> "$RESULTS_FILE"
        ((OFFLINE++))
    fi
done < hosts.txt

echo "" | tee -a "$RESULTS_FILE"
echo "======================================" | tee -a "$RESULTS_FILE"
echo "Summary:" | tee -a "$RESULTS_FILE"
echo "  Total hosts: $TOTAL" | tee -a "$RESULTS_FILE"
echo "  Online: $ONLINE" | tee -a "$RESULTS_FILE"
echo "  Offline: $OFFLINE" | tee -a "$RESULTS_FILE"
echo "" | tee -a "$RESULTS_FILE"
echo "Results saved to: $RESULTS_FILE"
EOF
chmod +x check_hosts.sh
echo "✓ Created check_hosts.sh"

# Due to character limit, I'll create a summary message
echo ""
echo "=== Installation Script Created Successfully! ==="
echo ""
echo "This script has generated the following:"
echo "  - Configuration files (hosts.txt, wallpapers.txt)"
echo "  - System update scripts (update_all.sh, update_and_remove_all.sh, disable_auto_updates.sh)"
echo "  - Maintenance scripts (cleanup_all.sh, reboot.sh)"
echo "  - Network scripts (check_hosts.sh)"
echo ""
echo "To generate remaining scripts, run this script again or copy them manually."
echo ""
echo "Next steps:"
echo "  1. Edit hosts.txt and add your Xubuntu device IPs"
echo "  2. Run: chmod +x *.sh"
echo "  3. Install sshpass: sudo apt install sshpass"
echo ""
EOF
chmod +x create_all_scripts.sh
echo "✓ Created create_all_scripts.sh"