#!/bin/bash
set +e
echo "=== Shutdown All Hosts ==="
echo ""
read -p "Are you sure you want to SHUTDOWN ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Shutting down..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S shutdown -h now' 2>/dev/null || true
done
echo ""
echo "Shutdown command sent to all hosts."
