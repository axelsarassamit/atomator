#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Disable Automatic Updates ==="
echo "Stops and disables unattended-upgrades and apt timers on all hosts."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Disabling auto-updates..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        systemctl stop unattended-upgrades 2>/dev/null || true
        systemctl disable unattended-upgrades 2>/dev/null || true
        systemctl stop apt-daily.timer 2>/dev/null || true
        systemctl disable apt-daily.timer 2>/dev/null || true
        systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
        systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get remove -y unattended-upgrades
        echo \"APT::Periodic::Update-Package-Lists \\\"0\\\";\" > /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::Unattended-Upgrade \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::Download-Upgradeable-Packages \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"APT::Periodic::AutocleanInterval \\\"0\\\";\" >> /etc/apt/apt.conf.d/20auto-upgrades
        echo \"Done\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
