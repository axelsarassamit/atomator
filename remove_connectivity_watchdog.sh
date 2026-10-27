#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Remove Connectivity Watchdog ==="
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing watchdog..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
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
