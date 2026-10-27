#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Disable Automatic Updates ==="
echo "Stops and disables unattended-upgrades and apt timers on all hosts."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Disabling auto-updates..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
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
