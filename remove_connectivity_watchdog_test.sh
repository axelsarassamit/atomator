#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e

echo "=== Removing Connectivity Watchdog TEST MODE ==="
echo ""

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 exampleuser@"$host" 'sudo -n bash -c "
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
done
echo "All hosts processed."
