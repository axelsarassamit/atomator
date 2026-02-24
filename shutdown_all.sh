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
