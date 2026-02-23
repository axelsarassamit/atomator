#!/bin/bash
set +e
echo "=== Check Watchdog Status ==="
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S /usr/local/bin/watchdog-status.sh 2>/dev/null || echo "Watchdog not installed"' 2>/dev/null || echo "  Could not connect"
    echo ""
done
echo "Done."
