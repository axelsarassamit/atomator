#!/bin/bash

# ============================================================================
# Atomator - Remote Xubuntu Management - Quick Installer
# Creates all management scripts in /remote_tools/
# Run on your Debian server: sudo bash quick_install.sh
# ============================================================================

VERSION="02.01.00"

set -e

TARGET_DIR="/remote_tools"

echo "╔════════════════════════════════════════════════════════════════╗"
echo "║   Atomator - Remote Xubuntu Management  v.${VERSION}            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
echo "This will create all management scripts in: $TARGET_DIR"
echo ""

if [ "$EUID" -ne 0 ]; then
    echo "Please run as root: sudo bash quick_install.sh"
    exit 1
fi

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# Check for existing installation
if [ -f version.txt ]; then
    OLD_VERSION=$(head -1 version.txt 2>/dev/null)
    echo "Upgrading: v.${OLD_VERSION} -> v.${VERSION}"
else
    echo "Fresh install: v.${VERSION}"
fi
echo ""

echo "Installing required packages..."
apt-get update -qq
apt-get install -y sshpass wakeonlan bc curl
echo ""

# Create hosts.txt if missing
if [ ! -f hosts.txt ]; then
cat > hosts.txt << 'HOSTSEOF'
# Atomator - Host List
# One IP address per line. Lines starting with # are ignored.
#
# Example:
# 192.168.1.50
# 192.168.1.51
HOSTSEOF
echo "Created hosts.txt (empty - add your hosts)"
fi

# Create credentials.conf if missing
if [ ! -f credentials.conf ]; then
cat > credentials.conf << 'CREDEOF'
SSH_USER=sweetagent
SSH_PASS=sweetcom
CREDEOF
chmod 600 credentials.conf
echo "Created credentials.conf (default credentials - change with menu)"
fi

# Create watchdog_hosts.conf if missing
if [ ! -f watchdog_hosts.conf ]; then
cat > watchdog_hosts.conf << 'WDEOF'
HOST_1=192.168.1.242
HOST_2=ntp.sweetserver.wan
HOST_3=
WDEOF
chmod 600 watchdog_hosts.conf
echo "Created watchdog_hosts.conf (default watchdog ping hosts)"
fi

# Create updates directory
mkdir -p "$TARGET_DIR/updates"

# Write version file
echo "$VERSION" > version.txt
echo "$(date '+%Y-%m-%d %H:%M:%S')" >> version.txt

echo "Creating scripts..."
echo ""

# ============================================================================
# 1. update_all.sh
# ============================================================================
cat > update_all.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Update All Systems ==="
echo "Runs apt update, upgrade, autoremove and autoclean on all hosts."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Updating..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && apt-get autoclean -y"' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x update_all.sh
echo "  [1/37] update_all.sh"

# ============================================================================
# 2. update_and_remove_all.sh
# ============================================================================
cat > update_and_remove_all.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Update & Remove Old Kernels ==="
echo "Updates all systems and purges old kernel packages to free disk space."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Updating + purging old kernels..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge && apt-get autoclean -y"' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x update_and_remove_all.sh
echo "  [2/37] update_and_remove_all.sh"

# ============================================================================
# 3. disable_auto_updates.sh
# ============================================================================
cat > disable_auto_updates.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Disable Automatic Updates ==="
echo "Stops and disables unattended-upgrades and apt timers on all hosts."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Disabling auto-updates..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        systemctl stop unattended-upgrades 2>/dev/null || true
        systemctl disable unattended-upgrades 2>/dev/null || true
        systemctl stop apt-daily.timer 2>/dev/null || true
        systemctl disable apt-daily.timer 2>/dev/null || true
        systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
        systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get remove -y unattended-upgrades 2>/dev/null || true
        echo \"APT::Periodic::Update-Package-Lists \\\"0\\\";\" > /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::Unattended-Upgrade \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::Download-Upgradeable-Packages \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::AutocleanInterval \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"Done\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x disable_auto_updates.sh
echo "  [3/37] disable_auto_updates.sh"

# ============================================================================
# 4. cleanup_all.sh
# ============================================================================
cat > cleanup_all.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== System Cleanup ==="
echo "Cleans APT cache, old logs, temp files and trash on all hosts."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Cleaning up..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        apt-get clean -y
        apt-get autoclean -y
        apt-get autoremove -y
        journalctl --vacuum-time=7d 2>/dev/null || true
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/files/* 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/info/* 2>/dev/null || true
        rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
        echo \"Done\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x cleanup_all.sh
echo "  [4/37] cleanup_all.sh"

# ============================================================================
# 5. reboot.sh
# ============================================================================
cat > reboot.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Reboot All Hosts ==="
echo ""
read -p "Are you sure you want to reboot ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Rebooting..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S reboot' 2>/dev/null || true
done
echo ""
echo "Reboot command sent to all hosts."
EOF
chmod +x reboot.sh
echo "  [5/37] reboot.sh"

# ============================================================================
# 6. shutdown_all.sh
# ============================================================================
cat > shutdown_all.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Shutdown All Hosts ==="
echo ""
read -p "Are you sure you want to SHUTDOWN ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Shutting down..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S shutdown -h now' 2>/dev/null || true
done
echo ""
echo "Shutdown command sent to all hosts."
EOF
chmod +x shutdown_all.sh
echo "  [6/37] shutdown_all.sh"

# ============================================================================
# 7. check_hosts.sh (no credentials needed - ping only)
# ============================================================================
cat > check_hosts.sh << 'EOF'
#!/bin/bash
set +e
echo "=== Check Host Status ==="
echo "Pings every host to see which are online or offline."
echo ""
ONLINE=0; OFFLINE=0; TOTAL=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    TOTAL=$((TOTAL + 1))
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        echo -e "  \033[0;32m[ONLINE]\033[0m  $host"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[OFFLINE]\033[0m $host"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo ""
echo "Total: $TOTAL | Online: $ONLINE | Offline: $OFFLINE"
EOF
chmod +x check_hosts.sh
echo "  [7/37] check_hosts.sh"

# ============================================================================
# 8. wol_all.sh (no credentials needed - uses mac_addresses.txt)
# ============================================================================
cat > wol_all.sh << 'EOF'
#!/bin/bash
set +e
echo "=== Wake-on-LAN ==="
echo "Sends WOL magic packets to wake up all computers."
echo ""
MAC_FILE="mac_addresses.txt"
if [ ! -f "$MAC_FILE" ]; then
    echo "Error: $MAC_FILE not found! Run collect_mac_addresses.sh first."
    exit 1
fi
while IFS='|' read -r ip mac hostname; do
    ip=$(echo "$ip" | xargs); mac=$(echo "$mac" | xargs); hostname=$(echo "$hostname" | xargs)
    if [ -z "$mac" ] || echo "$ip" | grep -q "^#"; then continue; fi
    echo "  Waking $ip ($hostname) - MAC: $mac"
    for i in 1 2 3; do wakeonlan "$mac" 2>/dev/null || true; done
done < "$MAC_FILE"
echo ""
echo "WOL packets sent (3x per host). Wait 30-60s then check status."
EOF
chmod +x wol_all.sh
echo "  [8/37] wol_all.sh"

# ============================================================================
# 9. collect_mac_addresses.sh
# ============================================================================
cat > collect_mac_addresses.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect MAC Addresses ==="
echo "Gathers MAC addresses from all hosts for Wake-on-LAN."
echo ""
OUTPUT_FILE="mac_addresses.txt"
> "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    MAC_INFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'IFACE=$(ip route | grep default | awk "{print \$5}" | head -1); if [ -n "$IFACE" ]; then MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null); HOSTNAME=$(hostname); echo "$MAC|$HOSTNAME"; fi' 2>/dev/null) || true
    if [ -n "$MAC_INFO" ]; then
        MAC=$(echo "$MAC_INFO" | cut -d'|' -f1); HNAME=$(echo "$MAC_INFO" | cut -d'|' -f2)
        echo "$host | $MAC | $HNAME" >> "$OUTPUT_FILE"
        echo "  $host | $MAC | $HNAME"
    else
        echo "  $host | FAILED"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x collect_mac_addresses.sh
echo "  [9/37] collect_mac_addresses.sh"

# ============================================================================
# 10. change_dns.sh
# ============================================================================
cat > change_dns.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Change DNS Servers ==="
echo "Sets DNS to Cloudflare (1.1.1.1) + Google (8.8.8.8) + Quad9 (9.9.9.9)"
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Changing DNS..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -n \"\$CON_NAME\" ]; then
            nmcli con mod \"\$CON_NAME\" ipv4.dns \"1.1.1.1 8.8.8.8 9.9.9.9\"
            nmcli con mod \"\$CON_NAME\" ipv4.ignore-auto-dns yes
            nmcli con up \"\$CON_NAME\" 2>/dev/null || true
            echo \"DNS updated\"
        else
            echo \"No active ethernet connection\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x change_dns.sh
echo "  [10/37] change_dns.sh"

# ============================================================================
# 11. fix_static_ip.sh
# ============================================================================
cat > fix_static_ip.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Static IP ==="
echo "Converts the current DHCP address to a permanent static IP."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting static IP..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEV=\$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -1 | cut -d: -f1)
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -z \"\$CON_NAME\" ] || [ -z \"\$DEV\" ]; then echo \"No ethernet found\"; exit 1; fi
        CURRENT_IP=\$(nmcli -t -f IP4.ADDRESS device show \"\$DEV\" | head -1 | cut -d: -f2)
        GATEWAY=\$(nmcli -t -f IP4.GATEWAY device show \"\$DEV\" | head -1 | cut -d: -f2)
        DNS=\$(nmcli -t -f IP4.DNS device show \"\$DEV\" 2>/dev/null | head -1 | cut -d: -f2)
        [ -z \"\$DNS\" ] && DNS=\"1.1.1.1 8.8.8.8 9.9.9.9\"
        if [ -z \"\$CURRENT_IP\" ]; then echo \"Could not detect IP\"; exit 1; fi
        nmcli con mod \"\$CON_NAME\" ipv4.method manual ipv4.addresses \"\$CURRENT_IP\" ipv4.gateway \"\$GATEWAY\" ipv4.dns \"\$DNS\" ipv4.ignore-auto-dns yes
        nmcli con up \"\$CON_NAME\" 2>/dev/null || true
        echo \"Static IP: \$CURRENT_IP gw \$GATEWAY dns \$DNS\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x fix_static_ip.sh
echo "  [11/37] fix_static_ip.sh"

# ============================================================================
# 12. remove_vpn_reset_network.sh
# ============================================================================
cat > remove_vpn_reset_network.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Remove VPN & Reset Network ==="
echo "Removes all VPN packages/connections and resets to static IP with DNS."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing VPN + resetting..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge openvpn wireguard wireguard-tools network-manager-openvpn network-manager-vpnc network-manager-pptp network-manager-l2tp 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        for conn in \$(nmcli -t -f NAME,TYPE connection show | grep -E \"vpn|wireguard|tun|openvpn\" | cut -d: -f1); do
            nmcli connection delete \"\$conn\" 2>/dev/null || true
        done
        rm -rf /etc/openvpn/* /etc/wireguard/* 2>/dev/null || true
        DEV=\$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -1 | cut -d: -f1)
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -n \"\$CON_NAME\" ] && [ -n \"\$DEV\" ]; then
            CURRENT_IP=\$(nmcli -t -f IP4.ADDRESS device show \"\$DEV\" | head -1 | cut -d: -f2)
            GATEWAY=\$(nmcli -t -f IP4.GATEWAY device show \"\$DEV\" | head -1 | cut -d: -f2)
            DNS=\$(nmcli -t -f IP4.DNS device show \"\$DEV\" 2>/dev/null | head -1 | cut -d: -f2)
            [ -z \"\$DNS\" ] && DNS=\"1.1.1.1 8.8.8.8 9.9.9.9\"
            nmcli con mod \"\$CON_NAME\" ipv4.method manual ipv4.addresses \"\$CURRENT_IP\" ipv4.gateway \"\$GATEWAY\" ipv4.dns \"\$DNS\" ipv4.ignore-auto-dns yes
            nmcli con up \"\$CON_NAME\" 2>/dev/null || true
            echo \"VPN removed. Static IP: \$CURRENT_IP DNS: \$DNS\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x remove_vpn_reset_network.sh
echo "  [12/37] remove_vpn_reset_network.sh"

# ============================================================================
# 13. require_sudo_network.sh
# ============================================================================
cat > require_sudo_network.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Lock Network Settings ==="
echo "Requires sudo password to change network settings (polkit rule)."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Locking network..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        mkdir -p /etc/polkit-1/localauthority/50-local.d
        cat > /etc/polkit-1/localauthority/50-local.d/restrict-network.pkla << POLKIT
[Restrict Network Manager]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.*
ResultAny=auth_admin
ResultInactive=auth_admin
ResultActive=auth_admin
POLKIT
        echo \"Network locked\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x require_sudo_network.sh
echo "  [13/37] require_sudo_network.sh"

# ============================================================================
# 14. speedtest_all.sh
# ============================================================================
cat > speedtest_all.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Speed Test All Hosts ==="
echo ""
OUTPUT_FILE="speedtest_results_$(date +%Y%m%d_%H%M%S).txt"
echo "Speed Test - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Testing (takes a moment)..."
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "which speedtest-cli >/dev/null 2>&1 || apt-get install -y speedtest-cli >/dev/null 2>&1; speedtest-cli --simple 2>/dev/null || echo \"Failed\""' 2>/dev/null) || true
    echo "  $RESULT"
    echo -e "\n$host:\n$RESULT" >> "$OUTPUT_FILE"
done
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x speedtest_all.sh
echo "  [14/37] speedtest_all.sh"

# ============================================================================
# 15. disable_wifi.sh
# ============================================================================
cat > disable_wifi.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Disable WiFi ==="
echo "Permanently disables WiFi on all hosts via rfkill and NetworkManager."
echo ""
LOCAL_SCRIPT="/tmp/_disable_wifi.sh"
REMOTE_SCRIPT="/tmp/_disable_wifi.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
nmcli radio wifi off 2>/dev/null || true
rfkill block wifi 2>/dev/null || true
for iface in $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1); do
    nmcli device disconnect "$iface" 2>/dev/null || true
done
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/disable-wifi.conf << NMCONF
[device-wifi]
wifi.scan-rand-mac-address=no
managed=0
NMCONF
cat > /etc/modprobe.d/disable-wifi.conf << MODCONF
blacklist ath9k
blacklist ath9k_htc
blacklist rt2800usb
blacklist iwlwifi
blacklist iwldvm
blacklist iwlmvm
blacklist rtl8xxxu
blacklist brcmfmac
MODCONF
systemctl restart NetworkManager 2>/dev/null || true
echo "WiFi disabled permanently"
SCRIPT
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Disabling WiFi..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done."
EOF
chmod +x disable_wifi.sh
echo "  [15/37] disable_wifi.sh"

# ============================================================================
# 16. collect_hardware_info.sh
# ============================================================================
cat > collect_hardware_info.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect Hardware Info ==="
echo "Gathers hostname, manufacturer, model, CPU, RAM, disk from all hosts."
echo ""
OUTPUT_FILE="hardware_info_$(date +%Y%m%d_%H%M%S).txt"
echo "Hardware Report - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Collecting..."
    INFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        echo \"  Hostname:     \$(hostname)\"
        echo \"  Manufacturer: \$(dmidecode -s system-manufacturer 2>/dev/null || echo N/A)\"
        echo \"  Model:        \$(dmidecode -s system-product-name 2>/dev/null || echo N/A)\"
        echo \"  Serial:       \$(dmidecode -s system-serial-number 2>/dev/null || echo N/A)\"
        echo \"  CPU:          \$(grep -m1 \"model name\" /proc/cpuinfo | cut -d: -f2 | xargs)\"
        echo \"  Cores:        \$(nproc)\"
        echo \"  RAM:          \$(free -h | awk \"/Mem:/{print \\\$2}\") total\"
        echo \"  Disk:         \$(df -h / | awk \"NR==2{print \\\$2 \\\" total, \\\" \\\$4 \\\" free}\")\"
        echo \"  OS:           \$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d \\\"\\\")\"
        echo \"  Kernel:       \$(uname -r)\"
        echo \"  Uptime:       \$(uptime -p)\"
    "' 2>/dev/null) || true
    echo "$INFO"
    echo -e "\n$host:\n$INFO" >> "$OUTPUT_FILE"
done
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x collect_hardware_info.sh
echo "  [16/37] collect_hardware_info.sh"

# ============================================================================
# 17. collect_ram_info.sh
# ============================================================================
cat > collect_ram_info.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect RAM Info ==="
echo ""
OUTPUT_FILE="ram_info_$(date +%Y%m%d_%H%M%S).txt"
echo "RAM Report - $(date)" > "$OUTPUT_FILE"
TOTAL_RAM=0; HOST_COUNT=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Collecting RAM..."
    INFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        echo \"  Hostname: \$(hostname)\"
        free -h | awk \"/Mem:/{print \\\"  Total: \\\" \\\$2 \\\"  Used: \\\" \\\$3 \\\"  Free: \\\" \\\$4}\"
    "' 2>/dev/null) || true
    RAM_MB=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" 'free -m | awk "/Mem:/{print \$2}"' 2>/dev/null) || true
    if [ -n "$RAM_MB" ] && [ "$RAM_MB" -gt 0 ] 2>/dev/null; then
        TOTAL_RAM=$((TOTAL_RAM + RAM_MB)); HOST_COUNT=$((HOST_COUNT + 1))
    fi
    echo "$INFO"
    echo -e "\n$host:\n$INFO" >> "$OUTPUT_FILE"
done
if [ $HOST_COUNT -gt 0 ]; then
    echo ""
    echo "Summary: $HOST_COUNT hosts | Total: $((TOTAL_RAM / 1024)) GB | Avg: $((TOTAL_RAM / HOST_COUNT / 1024)) GB/host"
fi
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x collect_ram_info.sh
echo "  [17/37] collect_ram_info.sh"

# ============================================================================
# 18. check_disk_space.sh
# ============================================================================
cat > check_disk_space.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Disk Space ==="
echo "Shows disk usage on all hosts. Warns if over 80%."
echo ""
OUTPUT_FILE="disk_space_$(date +%Y%m%d_%H%M%S).txt"
echo "Disk Space Report - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(df -h / | awk "NR==2{print \$5}" | tr -d "%")|$(df -h / | awk "NR==2{print \$2}")|$(df -h / | awk "NR==2{print \$4}")"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); USAGE=$(echo "$RESULT" | cut -d'|' -f2)
        TOTAL=$(echo "$RESULT" | cut -d'|' -f3); FREE=$(echo "$RESULT" | cut -d'|' -f4)
        if [ "$USAGE" -ge 90 ] 2>/dev/null; then
            echo -e "  \033[0;31m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **" >> "$OUTPUT_FILE"
        elif [ "$USAGE" -ge 80 ] 2>/dev/null; then
            echo -e "  \033[1;33m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *" >> "$OUTPUT_FILE"
        else
            echo -e "  \033[0;32m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free" >> "$OUTPUT_FILE"
        fi
    else
        echo -e "  \033[0;31m[----]\033[0m $host - Could not connect"
        echo "[----] $host - Could not connect" >> "$OUTPUT_FILE"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x check_disk_space.sh
echo "  [18/37] check_disk_space.sh"

# ============================================================================
# 19-20. install/uninstall_firefox.sh
# ============================================================================
cat > install_firefox.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Firefox ==="
echo "Installs Firefox and creates a desktop shortcut."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Firefox..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y firefox 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr 2>/dev/null || true
        for user_home in /home/*; do
            user=\$(basename \"\$user_home\")
            if [ -d \"\$user_home/Desktop\" ]; then
                cp /usr/share/applications/firefox*.desktop \"\$user_home/Desktop/\" 2>/dev/null || true
                chmod +x \"\$user_home/Desktop/firefox\"*.desktop 2>/dev/null || true
                chown \"\$user:\$user\" \"\$user_home/Desktop/firefox\"*.desktop 2>/dev/null || true
            fi
        done
        echo \"Firefox installed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x install_firefox.sh
echo "  [19/37] install_firefox.sh"

cat > uninstall_firefox.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Uninstall Firefox ==="
echo "Removes Firefox. User profiles (~/.mozilla) are kept."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing Firefox..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y firefox firefox-esr firefox-locale-* 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        rm -f /home/*/Desktop/firefox*.desktop 2>/dev/null || true
        echo \"Firefox removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x uninstall_firefox.sh
echo "  [20/37] uninstall_firefox.sh"

# ============================================================================
# 21. install_hostname_display.sh
# ============================================================================
cat > install_hostname_display.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Hostname Display ==="
echo "Installs conky to show hostname in bottom-right corner of desktop."
echo ""
LOCAL_SCRIPT="/tmp/_install_hostname_display.sh"
REMOTE_SCRIPT="/tmp/_install_hostname_display.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get install -y conky-all
HOSTNAME_LABEL=$(hostname)
for user_home in /home/*; do
    user=$(basename "$user_home")
    id "$user" &>/dev/null || continue
    mkdir -p "$user_home/.config"
    cat > "$user_home/.config/conky_hostname.conf" << CONKYCONF
conky.config = {
    alignment = 'bottom_right',
    background = true,
    double_buffer = true,
    font = 'DejaVu Sans:bold:size=14',
    gap_x = 20,
    gap_y = 20,
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    draw_shads = true,
    default_shade_color = '000000',
    update_interval = 60,
    use_xft = true,
};
conky.text = [[
\${color white}$HOSTNAME_LABEL
]];
CONKYCONF
    chown "$user:$user" "$user_home/.config/conky_hostname.conf"
    mkdir -p "$user_home/.config/autostart"
    cat > "$user_home/.config/autostart/conky-hostname.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=Hostname Display
Exec=bash -c "sleep 5 && conky -c $user_home/.config/conky_hostname.conf"
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP
    chown "$user:$user" "$user_home/.config/autostart/conky-hostname.desktop"
done
echo "Hostname display installed"
SCRIPT
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done. Shows after next login/reboot."
EOF
chmod +x install_hostname_display.sh
echo "  [21/37] install_hostname_display.sh"

# ============================================================================
# 22-23. install/remove_wine.sh
# ============================================================================
cat > install_wine.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Wine ==="
echo "Installs Wine to run Windows .exe files."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Wine (takes a while)..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        dpkg --add-architecture i386 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y wine wine64 wine32 winetricks 2>/dev/null || true
        echo \"Wine installed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done. Run .exe files with: wine program.exe"
EOF
chmod +x install_wine.sh
echo "  [22/37] install_wine.sh"

cat > remove_wine.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Remove Wine ==="
echo "Removes Wine and cleans up config directories."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing Wine..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y wine wine64 wine32 winetricks wine-stable 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        rm -rf /home/*/.wine 2>/dev/null || true
        echo \"Wine removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x remove_wine.sh
echo "  [23/37] remove_wine.sh"

# ============================================================================
# 24. set_wallpaper.sh
# ============================================================================
cat > set_wallpaper.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Set Wallpaper ==="
echo "Downloads a random wallpaper from wallpapers.txt and applies it."
echo ""
WALLPAPER_FILE="wallpapers.txt"
if [ ! -f "$WALLPAPER_FILE" ]; then echo "Error: $WALLPAPER_FILE not found!"; exit 1; fi
URLS=($(grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$"))
if [ ${#URLS[@]} -eq 0 ]; then echo "No URLs in $WALLPAPER_FILE"; exit 1; fi
RANDOM_URL="${URLS[$RANDOM % ${#URLS[@]}]}"
echo "Wallpaper: $RANDOM_URL"
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting wallpaper..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c '
        wget -q -O /tmp/wallpaper.jpg \"$RANDOM_URL\" 2>/dev/null || curl -sL -o /tmp/wallpaper.jpg \"$RANDOM_URL\" 2>/dev/null
        cp /tmp/wallpaper.jpg /usr/share/backgrounds/remote_wallpaper.jpg 2>/dev/null
        for user_home in /home/*; do
            user=\$(basename \"\$user_home\")
            id \"\$user\" &>/dev/null || continue
            for mon in monitor0 monitorDP-1 monitorHDMI-1 monitorVGA-1; do
                su - \"\$user\" -c \"DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u \$user)/bus xfconf-query -c xfce4-desktop -p /backdrop/screen0/\$mon/workspace0/last-image -s /usr/share/backgrounds/remote_wallpaper.jpg 2>/dev/null\" || true
            done
        done
        rm -f /tmp/wallpaper.jpg
        echo \"Wallpaper set\"
    '" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x set_wallpaper.sh
echo "  [24/37] set_wallpaper.sh"

# ============================================================================
# 25. restrict_chromium_cpu.sh
# ============================================================================
cat > restrict_chromium_cpu.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Restrict Chromium CPU ==="
echo "Limits Chromium to 50% CPU using cpulimit systemd service."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting up CPU limiter..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y cpulimit 2>/dev/null || true
        cat > /etc/systemd/system/chromium-cpu-limit.service << SERVICE
[Unit]
Description=Chromium CPU Limiter
After=multi-user.target
[Service]
Type=simple
ExecStart=/bin/bash -c \"while true; do for pid in \\\$(pgrep -f chromium); do cpulimit -p \\\$pid -l 50 -z 2>/dev/null & done; sleep 10; done\"
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE
        systemctl daemon-reload
        systemctl enable chromium-cpu-limit.service
        systemctl start chromium-cpu-limit.service
        echo \"Chromium limited to 50% CPU\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x restrict_chromium_cpu.sh
echo "  [25/37] restrict_chromium_cpu.sh"

# ============================================================================
# 26. manage_wallpapers.sh (no credentials needed - local file management)
# ============================================================================
cat > manage_wallpapers.sh << 'EOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
WALLPAPER_FILE="wallpapers.txt"
if [ ! -f "$WALLPAPER_FILE" ]; then
    touch "$WALLPAPER_FILE"
    echo -e "${YELLOW}Created empty $WALLPAPER_FILE${NC}"
fi
while true; do
    echo ""
    echo -e "${CYAN}=== Manage Wallpapers ===${NC}"
    TOTAL=$(grep -v "^#" "$WALLPAPER_FILE" 2>/dev/null | grep -v "^$" | wc -l | tr -d ' ')
    echo -e "${YELLOW}  URLs loaded: ${TOTAL}${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} View all URLs"
    echo -e "${YELLOW}2.${NC} Add a URL"
    echo -e "${YELLOW}3.${NC} Remove a URL"
    echo -e "${YELLOW}4.${NC} Remove all URLs"
    echo -e "${YELLOW}5.${NC} Edit wallpapers.txt"
    echo -e "${YELLOW}0.${NC} Back"
    echo ""
    read -p "Choice [0-5]: " choice
    echo ""
    case $choice in
        1) if [ "$TOTAL" -eq 0 ]; then echo -e "${RED}No wallpaper URLs found.${NC}"; else echo -e "${GREEN}Wallpaper URLs:${NC}"; echo ""; grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | cat -n; fi ;;
        2) echo -ne "${YELLOW}URL to add: ${NC}"; read url; if [ -z "$url" ]; then echo -e "${RED}No URL entered.${NC}"; else echo "$url" >> "$WALLPAPER_FILE"; echo -e "${GREEN}Added: $url${NC}"; fi ;;
        3) if [ "$TOTAL" -eq 0 ]; then echo -e "${RED}No URLs to remove.${NC}"; else echo -e "${GREEN}Current URLs:${NC}"; echo ""; grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | cat -n; echo ""; echo -ne "${YELLOW}Line number to remove (or 0 to cancel): ${NC}"; read num; if [ "$num" = "0" ] || [ -z "$num" ]; then echo "Cancelled."; else URL=$(grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | sed -n "${num}p"); if [ -n "$URL" ]; then cp "$WALLPAPER_FILE" "${WALLPAPER_FILE}.bak"; grep -vF "$URL" "$WALLPAPER_FILE" > "${WALLPAPER_FILE}.tmp"; mv "${WALLPAPER_FILE}.tmp" "$WALLPAPER_FILE"; echo -e "${GREEN}Removed: $URL${NC}"; else echo -e "${RED}Invalid line number.${NC}"; fi; fi; fi ;;
        4) read -p "Remove ALL wallpaper URLs? (yes/no): " confirm; if [ "$confirm" = "yes" ]; then cp "$WALLPAPER_FILE" "${WALLPAPER_FILE}.bak"; > "$WALLPAPER_FILE"; echo -e "${GREEN}All URLs removed. Backup saved.${NC}"; else echo "Cancelled."; fi ;;
        5) ${EDITOR:-nano} "$WALLPAPER_FILE" ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
EOF
chmod +x manage_wallpapers.sh
echo "  [26/37] manage_wallpapers.sh"

# ============================================================================
# 27. run_remote_command.sh
# ============================================================================
cat > run_remote_command.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Run Custom Command ==="
echo "Execute any command on all hosts."
echo ""
read -p "Command (runs as root): " CMD
if [ -z "$CMD" ]; then echo "No command entered."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c '$CMD'" 2>&1 || true
    echo ""
done
echo "Done."
EOF
chmod +x run_remote_command.sh
echo "  [27/37] run_remote_command.sh"

# ============================================================================
# 28. delete_ssh_keys.sh (no credentials needed - local only)
# ============================================================================
cat > delete_ssh_keys.sh << 'EOF'
#!/bin/bash
set +e
echo "=== Delete SSH Keys (Local) ==="
echo "Removes all SSH keys on THIS machine and regenerates host keys."
echo "This does NOT affect remote hosts."
echo ""
read -p "Delete ALL SSH keys on this machine? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for user_home in /home/*; do
    if [ -d "$user_home/.ssh" ]; then
        rm -f "$user_home/.ssh/id_"* "$user_home/.ssh/authorized_keys" "$user_home/.ssh/known_hosts"
        echo "  Cleaned: $user_home/.ssh/"
    fi
done
if [ -d /root/.ssh ]; then
    rm -f /root/.ssh/id_* /root/.ssh/authorized_keys /root/.ssh/known_hosts
    echo "  Cleaned: /root/.ssh/"
fi
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A 2>/dev/null || dpkg-reconfigure openssh-server 2>/dev/null || true
echo ""
echo "SSH keys deleted, host keys regenerated."
echo "Done."
EOF
chmod +x delete_ssh_keys.sh
echo "  [28/37] delete_ssh_keys.sh"

# ============================================================================
# 29. check_uptime.sh
# ============================================================================
cat > check_uptime.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Uptime ==="
echo "Shows how long each host has been running."
echo ""
OUTPUT_FILE="uptime_$(date +%Y%m%d_%H%M%S).txt"
echo "Uptime Report - $(date)" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(uptime -p)|$(uptime -s)"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); UP=$(echo "$RESULT" | cut -d'|' -f2); SINCE=$(echo "$RESULT" | cut -d'|' -f3)
        echo "  $host ($HNAME) - $UP (since $SINCE)"
        echo "$host ($HNAME) - $UP (since $SINCE)" >> "$OUTPUT_FILE"
    else
        echo -e "  $host - \033[0;31mOFFLINE\033[0m"
        echo "$host - OFFLINE" >> "$OUTPUT_FILE"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x check_uptime.sh
echo "  [29/37] check_uptime.sh"

# ============================================================================
# 30. check_services.sh
# ============================================================================
cat > check_services.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Services ==="
echo "Shows status of important services on all hosts."
echo ""
OUTPUT_FILE="services_$(date +%Y%m%d_%H%M%S).txt"
echo "Services Report - $(date)" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
SERVICES="ssh NetworkManager cron rsyslog"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    echo "--- [$host] ---" >> "$OUTPUT_FILE"
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "for svc in $SERVICES; do
            STATUS=\$(systemctl is-active \$svc 2>/dev/null || echo 'not found')
            if [ \"\$STATUS\" = 'active' ]; then echo \"  [OK]   \$svc\"; else echo \"  [FAIL] \$svc (\$STATUS)\"; fi
        done" 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo "$RESULT"
        echo "$RESULT" >> "$OUTPUT_FILE"
    else
        echo "  Could not connect"
        echo "  Could not connect" >> "$OUTPUT_FILE"
    fi
    echo ""
    echo "" >> "$OUTPUT_FILE"
done
echo "Saved to: $OUTPUT_FILE"
EOF
chmod +x check_services.sh
echo "  [30/37] check_services.sh"

# ============================================================================
# 31-33. Watchdog scripts
# ============================================================================
cat > install_connectivity_watchdog.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
source ./watchdog_hosts.conf 2>/dev/null || { echo "ERROR: watchdog_hosts.conf not found!"; exit 1; }
echo "=== Install Connectivity Watchdog ==="
echo "72-hour self-destruct if configured hosts are unreachable."
echo ""
echo "Configured hosts:"
echo "  Host 1: ${HOST_1:-not set}"
echo "  Host 2: ${HOST_2:-not set}"
[ -n "$HOST_3" ] && echo "  Host 3: $HOST_3"
echo ""
echo "WARNING: This installs a REAL self-destruct mechanism!"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
LOCAL_SCRIPT="/tmp/_install_watchdog.sh"
REMOTE_SCRIPT="/tmp/_install_watchdog.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
mkdir -p /var/lib/connectivity-watchdog
cat > /usr/local/bin/connectivity-watchdog.sh << 'WATCHDOG'
#!/bin/bash
PRIMARY_HOST="__HOST_1__"
SECONDARY_HOST="__HOST_2__"
TERTIARY_HOST="__HOST_3__"
TIMEOUT_SECONDS=259200
STATE_FILE="/var/lib/connectivity-watchdog/state"
TIMER_FILE="/var/lib/connectivity-watchdog/timer"
mkdir -p /var/lib/connectivity-watchdog
check_connectivity() {
    ping -c 1 -W 2 "$PRIMARY_HOST" &>/dev/null && return 0
    ping -c 1 -W 2 "$SECONDARY_HOST" &>/dev/null && return 0
    [ -n "$TERTIARY_HOST" ] && ping -c 1 -W 2 "$TERTIARY_HOST" &>/dev/null && return 0
    return 1
}
perform_wipe() {
    logger -t connectivity-watchdog "CRITICAL: 72h timeout. Wiping system."
    for disk in $(lsblk -dpno NAME | grep -E "sd|nvme|vd"); do
        dd if=/dev/zero of="$disk" bs=1M count=1024 2>/dev/null &
    done
    wait; sync; poweroff -f
}
if check_connectivity; then
    if [ -f "$STATE_FILE" ]; then
        logger -t connectivity-watchdog "Connection restored. Timer reset."
        rm -f "$STATE_FILE" "$TIMER_FILE"
    fi
else
    if [ ! -f "$STATE_FILE" ]; then
        date +%s > "$STATE_FILE"
        logger -t connectivity-watchdog "Connection lost. 72h countdown started."
    else
        LOST_TIME=$(cat "$STATE_FILE"); CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - LOST_TIME)); echo "$ELAPSED" > "$TIMER_FILE"
        if [ $ELAPSED -ge $TIMEOUT_SECONDS ]; then perform_wipe
        else HOURS=$(( (TIMEOUT_SECONDS - ELAPSED) / 3600 )); logger -t connectivity-watchdog "No connection. ${HOURS}h remaining."; fi
    fi
fi
WATCHDOG
chmod +x /usr/local/bin/connectivity-watchdog.sh
cat > /etc/systemd/system/connectivity-watchdog.service << 'SERVICE'
[Unit]
Description=Connectivity Watchdog (72h self-destruct)
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/connectivity-watchdog.sh
[Install]
WantedBy=multi-user.target
SERVICE
cat > /etc/systemd/system/connectivity-watchdog.timer << 'TIMER'
[Unit]
Description=Connectivity Watchdog Timer (every 5 min)
[Timer]
OnBootSec=60sec
OnUnitActiveSec=300sec
Persistent=true
[Install]
WantedBy=timers.target
TIMER
cat > /usr/local/bin/watchdog-status.sh << 'STATUS'
#!/bin/bash
STATE_FILE="/var/lib/connectivity-watchdog/state"
echo "=== Connectivity Watchdog Status ==="
if systemctl is-active connectivity-watchdog.timer &>/dev/null; then echo "Service: ACTIVE"; else echo "Service: INACTIVE"; fi
if [ ! -f "$STATE_FILE" ]; then echo "Status: OK - Connected"
else
    LOST_TIME=$(cat "$STATE_FILE"); ELAPSED=$(($(date +%s) - LOST_TIME))
    echo "Status: WARNING - No connection"
    echo "Elapsed: $((ELAPSED/3600))h $(((ELAPSED%3600)/60))m"
    echo "Wipe in: $(((259200-ELAPSED)/3600))h $(( ((259200-ELAPSED)%3600)/60 ))m"
fi
STATUS
chmod +x /usr/local/bin/watchdog-status.sh
systemctl daemon-reload
systemctl enable connectivity-watchdog.timer
systemctl start connectivity-watchdog.timer
systemctl start connectivity-watchdog.service
echo "Watchdog installed (72h timeout, checks every 5min)"
SCRIPT
# Replace placeholders with actual host values
sed -i "s/__HOST_1__/$HOST_1/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_2__/$HOST_2/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_3__/$HOST_3/g" "$LOCAL_SCRIPT"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing watchdog..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done."
EOF
chmod +x install_connectivity_watchdog.sh
echo "  [31/37] install_connectivity_watchdog.sh"

cat > remove_connectivity_watchdog.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Remove Connectivity Watchdog ==="
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing watchdog..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        systemctl stop connectivity-watchdog.timer 2>/dev/null || true
        systemctl disable connectivity-watchdog.timer 2>/dev/null || true
        systemctl stop connectivity-watchdog.service 2>/dev/null || true
        rm -f /etc/systemd/system/connectivity-watchdog.service /etc/systemd/system/connectivity-watchdog.timer
        systemctl daemon-reload
        rm -f /usr/local/bin/connectivity-watchdog.sh /usr/local/bin/watchdog-status.sh
        rm -rf /var/lib/connectivity-watchdog
        echo \"Watchdog removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
EOF
chmod +x remove_connectivity_watchdog.sh
echo "  [32/37] remove_connectivity_watchdog.sh"

cat > check_watchdog_status.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Watchdog Status ==="
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S /usr/local/bin/watchdog-status.sh 2>/dev/null || echo "Watchdog not installed"' 2>/dev/null || echo "  Could not connect"
    echo ""
done
echo "Done."
EOF
chmod +x check_watchdog_status.sh
echo "  [33/37] check_watchdog_status.sh"

# ============================================================================
# 34. manage_hosts.sh (no credentials needed - local file management)
# ============================================================================
cat > manage_hosts.sh << 'EOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
HOSTS_FILE="hosts.txt"
fill_range() {
    echo -ne "${YELLOW}Enter IP range (e.g. 192.168.1.50-199): ${NC}"
    read RANGE
    BASE=$(echo "$RANGE" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.')
    START=$(echo "$RANGE" | grep -oE '\.[0-9]+-' | tr -d '.-')
    END=$(echo "$RANGE" | grep -oE -- '-[0-9]+$' | tr -d '-')
    if [ -z "$BASE" ] || [ -z "$START" ] || [ -z "$END" ]; then echo -e "${RED}Invalid format.${NC}"; return; fi
    cp "$HOSTS_FILE" "${HOSTS_FILE}.bak" 2>/dev/null
    echo "# Auto-generated on $(date)" > "$HOSTS_FILE"
    echo "# Range: ${BASE}${START} to ${BASE}${END}" >> "$HOSTS_FILE"
    COUNT=0
    for i in $(seq "$START" "$END"); do echo "${BASE}${i}" >> "$HOSTS_FILE"; COUNT=$((COUNT + 1)); done
    echo "# Total: $COUNT hosts" >> "$HOSTS_FILE"
    echo -e "${GREEN}Added $COUNT hosts${NC}"
}
while true; do
    echo ""
    echo -e "${CYAN}=== Manage hosts.txt ===${NC}"
    echo -e "${YELLOW}1.${NC} Fill with IP range"
    echo -e "${YELLOW}2.${NC} View hosts"
    echo -e "${YELLOW}3.${NC} Add a host"
    echo -e "${YELLOW}4.${NC} Remove a host"
    echo -e "${YELLOW}5.${NC} Remove duplicates"
    echo -e "${YELLOW}6.${NC} Sort hosts"
    echo -e "${YELLOW}7.${NC} Count hosts"
    echo -e "${YELLOW}8.${NC} Restore backup"
    echo -e "${YELLOW}0.${NC} Back"
    echo ""
    read -p "Choice [0-8]: " choice
    echo ""
    case $choice in
        1) fill_range ;;
        2) grep -v "^#" "$HOSTS_FILE" | grep -v "^$" | cat -n ;;
        3) read -p "IP to add: " ip; echo "$ip" >> "$HOSTS_FILE"; echo -e "${GREEN}Added: $ip${NC}" ;;
        4) read -p "IP to remove: " ip; sed -i.bak "/$ip/d" "$HOSTS_FILE"; echo -e "${GREEN}Removed: $ip${NC}" ;;
        5) cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"; sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$HOSTS_FILE" | uniq > "${HOSTS_FILE}.tmp"; mv "${HOSTS_FILE}.tmp" "$HOSTS_FILE"; echo -e "${GREEN}Done.${NC}" ;;
        6) cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"; sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$HOSTS_FILE" > "${HOSTS_FILE}.tmp"; mv "${HOSTS_FILE}.tmp" "$HOSTS_FILE"; echo -e "${GREEN}Sorted.${NC}" ;;
        7) echo "Hosts: $(grep -v "^#" "$HOSTS_FILE" | grep -v "^$" | wc -l)" ;;
        8) if [ -f "${HOSTS_FILE}.bak" ]; then cp "${HOSTS_FILE}.bak" "$HOSTS_FILE"; echo -e "${GREEN}Restored.${NC}"; else echo -e "${RED}No backup.${NC}"; fi ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
EOF
chmod +x manage_hosts.sh
echo "  [34/37] manage_hosts.sh"

# ============================================================================
# 35. change_password.sh (NEW)
# ============================================================================
cat > change_password.sh << 'EOF'
#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Change Remote Password ==="
echo "Changes the password for $SSH_USER on all remote hosts."
echo ""
echo -ne "New password: "
read -s NEW_PASS
echo ""
echo -ne "Confirm password: "
read -s CONFIRM_PASS
echo ""
echo ""
if [ -z "$NEW_PASS" ]; then echo "No password entered."; exit 1; fi
if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then echo "Passwords do not match!"; exit 1; fi
echo "This will change the password for '$SSH_USER' on ALL hosts."
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
SUCCESS=0; FAILED=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Changing password..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c 'printf \"%s:%s\" \"$SSH_USER\" \"$NEW_PASS\" | chpasswd'" 2>&1 && {
        echo "[$host] OK"
        SUCCESS=$((SUCCESS + 1))
    } || {
        echo "[$host] FAILED"
        FAILED=$((FAILED + 1))
    }
done
echo ""
echo "Results: $SUCCESS OK, $FAILED FAILED"
if [ $SUCCESS -gt 0 ]; then
    cp credentials.conf credentials.conf.bak
    sed -i "s/^SSH_PASS=.*/SSH_PASS=$NEW_PASS/" credentials.conf
    echo ""
    echo "credentials.conf updated with new password."
    echo "Old credentials backed up to credentials.conf.bak"
fi
echo ""
echo "Done."
EOF
chmod +x change_password.sh
echo "  [35/37] change_password.sh"

# ============================================================================
# 36. configure_watchdog_hosts.sh (NEW - no credentials needed)
# ============================================================================
cat > configure_watchdog_hosts.sh << 'EOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
CONFIG_FILE="watchdog_hosts.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'DEFAULTS'
HOST_1=192.168.1.242
HOST_2=ntp.sweetserver.wan
HOST_3=
DEFAULTS
    chmod 600 "$CONFIG_FILE"
    echo -e "${YELLOW}Created $CONFIG_FILE with defaults.${NC}"
fi
source "$CONFIG_FILE" 2>/dev/null
while true; do
    echo ""
    echo -e "${CYAN}=== Configure Watchdog Ping Hosts ===${NC}"
    echo ""
    echo -e "  Host 1: ${GREEN}${HOST_1:-empty}${NC}"
    echo -e "  Host 2: ${GREEN}${HOST_2:-empty}${NC}"
    echo -e "  Host 3: ${GREEN}${HOST_3:-empty}${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Change Host 1"
    echo -e "  ${YELLOW}2.${NC} Change Host 2"
    echo -e "  ${YELLOW}3.${NC} Change Host 3"
    echo -e "  ${YELLOW}4.${NC} Test ping all hosts"
    echo -e "  ${YELLOW}5.${NC} Save and reinstall watchdog"
    echo -e "  ${YELLOW}0.${NC} Back"
    echo ""
    read -p "  Choice [0-5]: " choice
    echo ""
    case $choice in
        1) read -p "  New Host 1 (IP or hostname): " new_host; if [ -n "$new_host" ]; then HOST_1="$new_host"; echo -e "${GREEN}Host 1 set to: $HOST_1${NC}"; fi ;;
        2) read -p "  New Host 2 (IP or hostname): " new_host; if [ -n "$new_host" ]; then HOST_2="$new_host"; echo -e "${GREEN}Host 2 set to: $HOST_2${NC}"; fi ;;
        3) read -p "  New Host 3 (IP or hostname, empty to clear): " new_host; HOST_3="$new_host"; if [ -n "$HOST_3" ]; then echo -e "${GREEN}Host 3 set to: $HOST_3${NC}"; else echo -e "${YELLOW}Host 3 cleared.${NC}"; fi ;;
        4)
            echo "Testing hosts..."
            for h in "$HOST_1" "$HOST_2" "$HOST_3"; do
                [ -z "$h" ] && continue
                if ping -c 1 -W 2 "$h" &>/dev/null; then echo -e "  ${GREEN}[OK]${NC} $h"; else echo -e "  ${RED}[FAIL]${NC} $h"; fi
            done
            ;;
        5)
            COUNT=0
            [ -n "$HOST_1" ] && COUNT=$((COUNT + 1))
            [ -n "$HOST_2" ] && COUNT=$((COUNT + 1))
            [ -n "$HOST_3" ] && COUNT=$((COUNT + 1))
            if [ $COUNT -lt 2 ]; then
                echo -e "${RED}Minimum 2 hosts required! Currently: $COUNT${NC}"
            else
                cat > "$CONFIG_FILE" << SAVECONF
HOST_1=$HOST_1
HOST_2=$HOST_2
HOST_3=$HOST_3
SAVECONF
                chmod 600 "$CONFIG_FILE"
                echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
                echo ""
                read -p "  Reinstall watchdog with new hosts? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                    if [ -f "./install_connectivity_watchdog.sh" ]; then bash ./install_connectivity_watchdog.sh; else echo -e "${RED}install_connectivity_watchdog.sh not found!${NC}"; fi
                fi
            fi
            ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
EOF
chmod +x configure_watchdog_hosts.sh
echo "  [36/37] configure_watchdog_hosts.sh"

# ============================================================================
# 37. update.sh
# ============================================================================
cat > update.sh << 'EOF'
#!/bin/bash
set +e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
TARGET_DIR="/remote_tools"
GITHUB_URL="https://raw.githubusercontent.com/axelsarassamit/atomator/main/quick_install.sh"

echo -e "${CYAN}=== Atomator - Update Scripts ===${NC}"
echo ""

# Show current version
if [ -f "$TARGET_DIR/version.txt" ]; then
    CURRENT=$(head -1 "$TARGET_DIR/version.txt")
    INSTALLED=$(tail -1 "$TARGET_DIR/version.txt")
    echo -e "  Current version:   ${GREEN}v.${CURRENT}${NC}  (installed ${INSTALLED})"
else
    CURRENT="unknown"
    echo -e "  Current version:   ${RED}unknown${NC}"
fi
echo ""

# Check for local update files
LOCAL_FILE=$(ls -1 "$TARGET_DIR"/updates/update_v*.sh 2>/dev/null | sort -V | tail -1)
if [ -z "$LOCAL_FILE" ]; then
    LOCAL_FILE=$(ls -1 "$TARGET_DIR"/update_v*.sh 2>/dev/null | sort -V | tail -1)
fi

echo -e "${YELLOW}Update options:${NC}"
echo ""
if [ -n "$LOCAL_FILE" ]; then
    LOCAL_NAME=$(basename "$LOCAL_FILE")
    LOCAL_VER=$(echo "$LOCAL_NAME" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
    echo -e "  ${YELLOW}1.${NC} Update from local file  (${LOCAL_NAME} - v.${LOCAL_VER})"
else
    echo -e "  ${RED}1.${NC} Update from local file  (no update file found)"
fi
echo -e "  ${YELLOW}2.${NC} Download latest from GitHub"
echo -e "  ${YELLOW}3.${NC} Revert to a previous version"
echo -e "  ${RED}0.${NC} Cancel"
echo ""
read -p "  Choice [0-3]: " update_choice

case $update_choice in
    1)
        if [ -z "$LOCAL_FILE" ]; then
            echo ""
            echo -e "${RED}No local update file found.${NC}"
            exit 1
        fi
        UPDATE_FILE="$LOCAL_FILE"
        NEW_VERSION="$LOCAL_VER"
        ;;
    2)
        echo ""
        echo "Downloading from GitHub..."
        TMP_FILE="/tmp/automator_github_update.sh"
        curl -sL "$GITHUB_URL" -o "$TMP_FILE"
        if [ ! -s "$TMP_FILE" ]; then
            echo -e "${RED}Download failed. Check your internet connection.${NC}"
            exit 1
        fi
        NEW_VERSION=$(grep '^VERSION=' "$TMP_FILE" | head -1 | cut -d'"' -f2)
        if [ -z "$NEW_VERSION" ]; then
            echo -e "${RED}Could not detect version from downloaded file.${NC}"
            exit 1
        fi
        echo -e "  Downloaded version: ${YELLOW}v.${NEW_VERSION}${NC}"
        mkdir -p "$TARGET_DIR/updates"
        UPDATE_FILE="$TARGET_DIR/updates/update_v.${NEW_VERSION}.sh"
        cp "$TMP_FILE" "$UPDATE_FILE"
        chmod +x "$UPDATE_FILE"
        rm -f "$TMP_FILE"
        ;;
    3)
        echo ""
        echo -e "${CYAN}Available versions:${NC}"
        echo ""
        UPDATE_FILES=$(ls -1 "$TARGET_DIR"/updates/update_v*.sh 2>/dev/null | sort -V)
        if [ -z "$UPDATE_FILES" ]; then
            UPDATE_FILES=$(ls -1 "$TARGET_DIR"/update_v*.sh 2>/dev/null | sort -V)
        fi
        if [ -z "$UPDATE_FILES" ]; then
            echo -e "${RED}No previous versions found.${NC}"
            exit 1
        fi
        i=1
        declare -a VERSION_FILES
        while IFS= read -r f; do
            FNAME=$(basename "$f")
            FVER=$(echo "$FNAME" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
            if [ "$FVER" = "$CURRENT" ]; then
                echo -e "  ${YELLOW}${i}.${NC} ${FNAME}  ${GREEN}<-- current${NC}"
            else
                echo -e "  ${YELLOW}${i}.${NC} ${FNAME}"
            fi
            VERSION_FILES[$i]="$f"
            i=$((i + 1))
        done <<< "$UPDATE_FILES"
        echo ""
        read -p "  Select version [1-$((i-1))]: " ver_choice
        if [ -z "$ver_choice" ] || [ "$ver_choice" -lt 1 ] 2>/dev/null || [ "$ver_choice" -ge "$i" ] 2>/dev/null; then
            echo "Cancelled."
            exit 0
        fi
        UPDATE_FILE="${VERSION_FILES[$ver_choice]}"
        NEW_VERSION=$(basename "$UPDATE_FILE" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
        ;;
    *)
        echo "Cancelled."
        exit 0
        ;;
esac

echo ""

# Show changelog if available
if [ -f "$TARGET_DIR/CHANGELOG.md" ]; then
    echo -e "${CYAN}Version changes:${NC}"
    cat "$TARGET_DIR/CHANGELOG.md"
    echo ""
fi

# Version comparison
if [ "$CURRENT" = "$NEW_VERSION" ]; then
    echo -e "${YELLOW}Same version (v.${NEW_VERSION}). Reinstall anyway?${NC}"
    read -p "(yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
else
    echo -e "  Update: ${GREEN}v.${CURRENT}${NC} -> ${YELLOW}v.${NEW_VERSION}${NC}"
    read -p "Proceed? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
fi

echo ""

# Backup config files
echo "Backing up config files..."
for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "$TARGET_DIR/$f" ]; then
        cp "$TARGET_DIR/$f" "/root/${f}.backup"
        echo "  Backed up: $f -> /root/${f}.backup"
    fi
done
echo ""

# Run the installer
FILENAME=$(basename "$UPDATE_FILE")
echo "Running $FILENAME..."
echo ""
bash "$UPDATE_FILE"

# Restore config files if missing
for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "/root/${f}.backup" ] && [ ! -f "$TARGET_DIR/$f" ]; then
        cp "/root/${f}.backup" "$TARGET_DIR/$f"
        echo "Restored: $f"
    fi
done

echo ""
echo -e "${GREEN}Update complete.${NC}"
echo "  Update file kept: $UPDATE_FILE"
EOF
chmod +x update.sh
echo "  [37/37] update.sh"

# ============================================================================
# CHANGELOG.md
# ============================================================================
cat > CHANGELOG.md << 'CLEOF'
# Atomator - Changelog

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

## v.02.00.00
- Submenu system (8 categories)
- Report viewers for all data collectors
- GitHub update support
- Delete SSH keys now local-only
- Timestamped output files

## v.01.00.00
- Initial complete rewrite
- 34 scripts with version system
- Update mechanism
CLEOF
echo ""
echo "  Created CHANGELOG.md"

# ============================================================================
# README.md (embedded for menu viewer)
# ============================================================================
cat > README.md << 'RDEOF'
# Atomator - Remote Xubuntu Management

A comprehensive remote management system for Xubuntu computers controlled
from a central Debian server via SSH.

## Quick Start

    sudo bash quick_install.sh    # Install all scripts
    bash /root/start.sh           # Launch menu

## Features

- 37 management scripts + interactive menu
- 8 category submenus: Updates, Network, Reports, Software, Config, Tools, Files, Update
- Credentials stored securely in credentials.conf (mode 600)
- Debug logging for menu navigation (max 10MB)
- Update catalog with version revert capability
- Configurable watchdog ping hosts (hidden 666 menu)
- Wake-on-LAN, DNS management, static IP, VPN removal
- Hardware/RAM/disk/uptime/services reports with timestamps
- Firefox, Wine, hostname display, wallpaper management
- Chromium CPU limiter, WiFi disabler
- 72-hour connectivity watchdog with self-destruct

## Files

- quick_install.sh    Master installer (generates everything)
- menu.sh             Interactive menu system
- update.sh           Update/revert mechanism
- credentials.conf    SSH credentials (mode 600)
- watchdog_hosts.conf Watchdog ping hosts (mode 600)
- hosts.txt           Target host IP addresses
- CHANGELOG.md        Version history
- updates/            Update file catalog

## Credentials

Default: sweetagent / sweetcom
Change via: Menu > Tools > Change remote password
File: credentials.conf (auto-created, mode 600)

## Updates

- Menu option 8: Update Scripts
- 3 options: local file, GitHub download, revert to previous version
- All versions kept in updates/ directory
- CHANGELOG.md shown during updates

## Version Format

v.XX.YY.AA where XX=major, YY=minor, AA=fix

## GitHub

https://github.com/axelsarassamit/atomator
RDEOF
echo "  Created README.md"

# ============================================================================
# MENU
# ============================================================================
cat > menu.sh << 'EOF'
#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

VERSION=$(head -1 version.txt 2>/dev/null || echo "unknown")
INSTALLED=$(tail -1 version.txt 2>/dev/null || echo "unknown")

# Debug logging
LOG_FILE="debug.log"
LOG_MAX=10485760
log_action() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        [ "$size" -ge "$LOG_MAX" ] 2>/dev/null && mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Atomator  v.${VERSION}  -  Remote Xubuntu Management          ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}
pause() { echo ""; read -p "Press Enter to continue..."; }
run_script() {
    show_header
    echo -e "${GREEN}Running: $2${NC}"
    echo -e "${BLUE}Script:  $1${NC}"
    echo ""
    log_action "RUN: $1 ($2)"
    if [ -f "./$1" ]; then bash "./$1"; else echo -e "${RED}Error: $1 not found!${NC}"; fi
    log_action "DONE: $1"
    pause
}
view_latest() {
    show_header
    LATEST=$(ls -1t $1 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo -e "${GREEN}Latest: $LATEST${NC}"
        echo ""
        cat "$LATEST"
    else
        echo -e "${RED}No reports found.${NC}"
    fi
    log_action "VIEW: $1"
    pause
}

log_action "=== Menu started ==="

# ── SUBMENUS ──

menu_updates() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  SYSTEM UPDATES & MAINTENANCE${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Update all systems            (apt update + upgrade)"
        echo -e "   ${YELLOW}2.${NC} Update + remove old kernels   (frees disk space)"
        echo -e "   ${YELLOW}3.${NC} Disable automatic updates     (stops unattended-upgrades)"
        echo -e "   ${YELLOW}4.${NC} System cleanup                (cache, logs, trash)"
        echo -e "   ${YELLOW}5.${NC} Reboot all hosts"
        echo -e "   ${YELLOW}6.${NC} Shutdown all hosts"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-6]: " c
        log_action "SUBMENU updates: choice=$c"
        case $c in
            1) run_script "update_all.sh" "Update All Systems" ;;
            2) run_script "update_and_remove_all.sh" "Update + Remove Old Kernels" ;;
            3) run_script "disable_auto_updates.sh" "Disable Automatic Updates" ;;
            4) run_script "cleanup_all.sh" "System Cleanup" ;;
            5) run_script "reboot.sh" "Reboot All Hosts" ;;
            6) run_script "shutdown_all.sh" "Shutdown All Hosts" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_network() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  NETWORK${NC}"
        echo ""
        echo -e "   ${YELLOW} 1.${NC} Check host status             (ping all hosts)"
        echo -e "   ${YELLOW} 2.${NC} Wake-on-LAN                   (wake up all computers)"
        echo -e "   ${YELLOW} 3.${NC} Collect MAC addresses          (for WOL)"
        echo -e "   ${YELLOW} 4.${NC} View MAC addresses"
        echo -e "   ${YELLOW} 5.${NC} Change DNS servers             (Cloudflare + Google + Quad9)"
        echo -e "   ${YELLOW} 6.${NC} Fix static IP                  (set current IP as permanent)"
        echo -e "   ${YELLOW} 7.${NC} Remove VPN + reset network     (clean VPN, set static IP)"
        echo -e "   ${YELLOW} 8.${NC} Lock network settings          (require sudo for changes)"
        echo -e "   ${YELLOW} 9.${NC} Speed test all hosts"
        echo -e "   ${YELLOW}10.${NC} View latest speed test"
        echo -e "   ${YELLOW}11.${NC} Disable WiFi                   (permanent, all hosts)"
        echo ""
        echo -e "   ${RED} 0.${NC} Back"
        echo ""
        read -p "  Choice [0-11]: " c
        log_action "SUBMENU network: choice=$c"
        case $c in
            1)  run_script "check_hosts.sh" "Check Host Status" ;;
            2)  run_script "wol_all.sh" "Wake-on-LAN" ;;
            3)  run_script "collect_mac_addresses.sh" "Collect MAC Addresses" ;;
            4)  show_header
                echo -e "${GREEN}MAC Addresses:${NC}"
                echo ""
                if [ -f "./mac_addresses.txt" ]; then cat ./mac_addresses.txt; else echo -e "${RED}No MAC addresses collected yet. Run option 3 first.${NC}"; fi
                pause ;;
            5)  run_script "change_dns.sh" "Change DNS Servers" ;;
            6)  run_script "fix_static_ip.sh" "Fix Static IP" ;;
            7)  run_script "remove_vpn_reset_network.sh" "Remove VPN + Reset Network" ;;
            8)  run_script "require_sudo_network.sh" "Lock Network Settings" ;;
            9)  run_script "speedtest_all.sh" "Speed Test All Hosts" ;;
            10) view_latest "speedtest_results_*.txt" ;;
            11) run_script "disable_wifi.sh" "Disable WiFi" ;;
            0)  break ;;
            *)  echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_info() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  INFORMATION & REPORTS${NC}"
        echo ""
        echo -e "   ${YELLOW} 1.${NC} Collect hardware info          (CPU, RAM, disk, model)"
        echo -e "   ${YELLOW} 2.${NC} View latest hardware report"
        echo -e "   ${YELLOW} 3.${NC} Collect RAM info               (detailed memory report)"
        echo -e "   ${YELLOW} 4.${NC} View latest RAM report"
        echo -e "   ${YELLOW} 5.${NC} Check disk space               (warns if disk is full)"
        echo -e "   ${YELLOW} 6.${NC} View latest disk report"
        echo -e "   ${YELLOW} 7.${NC} Check uptime                   (how long each host is running)"
        echo -e "   ${YELLOW} 8.${NC} View latest uptime report"
        echo -e "   ${YELLOW} 9.${NC} Check services                 (SSH, NetworkManager, cron)"
        echo -e "   ${YELLOW}10.${NC} View latest services report"
        echo ""
        echo -e "   ${RED} 0.${NC} Back"
        echo ""
        read -p "  Choice [0-10]: " c
        log_action "SUBMENU info: choice=$c"
        case $c in
            1)  run_script "collect_hardware_info.sh" "Collect Hardware Info" ;;
            2)  view_latest "hardware_info_*.txt" ;;
            3)  run_script "collect_ram_info.sh" "Collect RAM Info" ;;
            4)  view_latest "ram_info_*.txt" ;;
            5)  run_script "check_disk_space.sh" "Check Disk Space" ;;
            6)  view_latest "disk_space_*.txt" ;;
            7)  run_script "check_uptime.sh" "Check Uptime" ;;
            8)  view_latest "uptime_*.txt" ;;
            9)  run_script "check_services.sh" "Check Services" ;;
            10) view_latest "services_*.txt" ;;
            0)  break ;;
            *)  echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_software() {
    while true; do
        show_header
        echo -e "${MAGENTA}  SOFTWARE${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Install Firefox"
        echo -e "   ${YELLOW}2.${NC} Uninstall Firefox"
        echo -e "   ${YELLOW}3.${NC} Install hostname display       (conky on desktop)"
        echo -e "   ${YELLOW}4.${NC} Install Wine                   (run Windows .exe files)"
        echo -e "   ${YELLOW}5.${NC} Remove Wine"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-5]: " c
        log_action "SUBMENU software: choice=$c"
        case $c in
            1) run_script "install_firefox.sh" "Install Firefox" ;;
            2) run_script "uninstall_firefox.sh" "Uninstall Firefox" ;;
            3) run_script "install_hostname_display.sh" "Install Hostname Display" ;;
            4) run_script "install_wine.sh" "Install Wine" ;;
            5) run_script "remove_wine.sh" "Remove Wine" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_config() {
    while true; do
        show_header
        echo -e "${MAGENTA}  CONFIGURATION${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Set wallpaper                  (random from wallpapers.txt)"
        echo -e "   ${YELLOW}2.${NC} Manage wallpaper URLs          (add, remove, view)"
        echo -e "   ${YELLOW}3.${NC} Restrict Chromium CPU          (limit to 50%)"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-3]: " c
        log_action "SUBMENU config: choice=$c"
        case $c in
            1) run_script "set_wallpaper.sh" "Set Wallpaper" ;;
            2) run_script "manage_wallpapers.sh" "Manage Wallpaper URLs" ;;
            3) run_script "restrict_chromium_cpu.sh" "Restrict Chromium CPU" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_tools() {
    while true; do
        show_header
        echo -e "${MAGENTA}  TOOLS${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Run custom command             (execute anything on all hosts)"
        echo -e "   ${YELLOW}2.${NC} Delete SSH keys (local)        (clean keys on this server)"
        echo -e "   ${YELLOW}3.${NC} Change remote password         (change SSH user password)"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-3]: " c
        log_action "SUBMENU tools: choice=$c"
        case $c in
            1) run_script "run_remote_command.sh" "Run Custom Command" ;;
            2) run_script "delete_ssh_keys.sh" "Delete SSH Keys (Local)" ;;
            3) run_script "change_password.sh" "Change Remote Password" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_files() {
    while true; do
        show_header
        echo -e "${MAGENTA}  FILE MANAGEMENT${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Manage hosts.txt               (add, remove, fill ranges)"
        echo -e "   ${YELLOW}2.${NC} View hosts.txt"
        echo -e "   ${YELLOW}3.${NC} Edit hosts.txt"
        echo -e "   ${YELLOW}4.${NC} View README"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-4]: " c
        log_action "SUBMENU files: choice=$c"
        case $c in
            1) run_script "manage_hosts.sh" "Manage hosts.txt" ;;
            2)
                show_header
                echo -e "${GREEN}Contents of hosts.txt:${NC}"
                echo ""
                if [ -f "./hosts.txt" ]; then cat -n ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; fi
                pause
                ;;
            3)
                show_header
                if [ -f "./hosts.txt" ]; then ${EDITOR:-nano} ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; pause; fi
                ;;
            4)
                show_header
                echo -e "${GREEN}README:${NC}"
                echo ""
                if [ -f "./README.md" ]; then less ./README.md; else echo -e "${RED}README.md not found!${NC}"; pause; fi
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

# ── MAIN MENU ──

while true; do
    show_header
    HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
    echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
    echo ""
    echo -e "   ${YELLOW}1.${NC} System Updates & Maintenance"
    echo -e "   ${YELLOW}2.${NC} Network"
    echo -e "   ${YELLOW}3.${NC} Information & Reports"
    echo -e "   ${YELLOW}4.${NC} Software"
    echo -e "   ${YELLOW}5.${NC} Configuration"
    echo -e "   ${YELLOW}6.${NC} Tools"
    echo -e "   ${YELLOW}7.${NC} File Management"
    echo -e "   ${YELLOW}8.${NC} Update Scripts"
    echo ""
    echo -e "   ${RED}0.${NC} Exit"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    read -p "  Choice [0-8]: " choice
    log_action "MAIN MENU: choice=$choice"
    echo ""

    case $choice in
        1) menu_updates ;;
        2) menu_network ;;
        3) menu_info ;;
        4) menu_software ;;
        5) menu_config ;;
        6) menu_tools ;;
        7) menu_files ;;
        8)
            show_header
            echo -e "${GREEN}Running: Update Scripts${NC}"
            echo ""
            log_action "RUN: update.sh"
            if [ -f "./update.sh" ]; then bash ./update.sh; else echo -e "${RED}update.sh not found!${NC}"; fi
            log_action "DONE: update.sh"
            pause
            ;;
        666)
            log_action "MENU: 666 Watchdog Controls"
            while true; do
                show_header
                echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${MAGENTA}║     Security Watchdog Controls                                ║${NC}"
                echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "   ${YELLOW}1.${NC} Install watchdog          (72h self-destruct if offline)"
                echo -e "   ${YELLOW}2.${NC} Remove watchdog"
                echo -e "   ${YELLOW}3.${NC} Check watchdog status"
                echo -e "   ${YELLOW}4.${NC} Change watchdog ping hosts"
                echo ""
                echo -e "   ${RED}0.${NC} Back to main menu"
                echo ""
                read -p "  Choice [0-4]: " wc
                log_action "SUBMENU 666: choice=$wc"
                echo ""
                case $wc in
                    1) run_script "install_connectivity_watchdog.sh" "Install Watchdog" ;;
                    2) run_script "remove_connectivity_watchdog.sh" "Remove Watchdog" ;;
                    3) run_script "check_watchdog_status.sh" "Check Watchdog Status" ;;
                    4) run_script "configure_watchdog_hosts.sh" "Configure Watchdog Hosts" ;;
                    0) break ;;
                    *) echo -e "${RED}Invalid choice.${NC}"; sleep 1 ;;
                esac
            done
            ;;
        0)
            log_action "EXIT"
            show_header
            echo -e "${GREEN}Goodbye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            sleep 1
            ;;
    esac
done
EOF
chmod +x menu.sh
echo ""
echo "  Created menu.sh"

# ============================================================================
# START.SH
# ============================================================================
cat > /root/start.sh << STARTEOF
#!/bin/bash
cd $TARGET_DIR && bash menu.sh
STARTEOF
chmod +x /root/start.sh
echo "  Created /root/start.sh"

# ============================================================================
# DONE
# ============================================================================
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║  Installation Complete!  v.${VERSION}                              ║"
echo "╠════════════════════════════════════════════════════════════════╣"
echo "║                                                              ║"
echo "║  Scripts installed to: /remote_tools/                        ║"
echo "║  Total: 37 scripts + menu                                   ║"
echo "║                                                              ║"
echo "║  Quick start:   bash /root/start.sh                         ║"
echo "║  Or:            cd /remote_tools && bash menu.sh            ║"
echo "║                                                              ║"
echo "║  Update:  Menu option 8, or run update.sh directly          ║"
echo "║           Supports local files, GitHub, and version revert  ║"
echo "║                                                              ║"
echo "║  Credentials: credentials.conf (change via Tools menu)      ║"
echo "║                                                              ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
chmod 700 "$TARGET_DIR"

# Generate update file in updates/ directory
mkdir -p "$TARGET_DIR/updates"
cp "$0" "$TARGET_DIR/updates/update_v.${VERSION}.sh" 2>/dev/null || cp "$TARGET_DIR/quick_install.sh" "$TARGET_DIR/updates/update_v.${VERSION}.sh" 2>/dev/null || true
chmod +x "$TARGET_DIR/updates/update_v.${VERSION}.sh" 2>/dev/null || true
echo "  Created updates/update_v.${VERSION}.sh (for future re-installs/reverts)"
