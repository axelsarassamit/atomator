#!/bin/bash
set +e

echo "=== Removing Connectivity Watchdog TEST MODE ==="
echo ""

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'echo sweetcom | sudo -S bash -c "
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
