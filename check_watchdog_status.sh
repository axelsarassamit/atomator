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
