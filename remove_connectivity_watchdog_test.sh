#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"

echo "=== Removing Connectivity Watchdog TEST MODE ==="
echo ""

run_host() {
    local host="$1"
    echo "Processing $host..."
    remote_exec "$host" 'sudo -n bash -ec "
        echo \"Removing Connectivity Watchdog TEST MODE...\"

        # Stop and disable timer
        systemctl stop connectivity-watchdog-test.timer 2>/dev/null || true
        systemctl disable connectivity-watchdog-test.timer 2>/dev/null || true

        # Stop service
        systemctl stop connectivity-watchdog-test.service 2>/dev/null || true

        # Remove systemd files
        rm -f /etc/systemd/system/connectivity-watchdog-test.service
        rm -f /etc/systemd/system/connectivity-watchdog-test.timer

        # Reload systemd
        systemctl daemon-reload

        # Remove scripts
        rm -f /usr/local/bin/connectivity-watchdog-test.sh
        rm -f /usr/local/bin/watchdog-test-status.sh

        # Remove state files
        rm -rf /var/lib/connectivity-watchdog-test

        # Remove log file
        rm -f /var/log/connectivity-watchdog-test.log

        echo \"✓ Connectivity Watchdog TEST MODE removed\"
    "' || true

    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
}
fleet_run run_host
echo "All hosts processed."
