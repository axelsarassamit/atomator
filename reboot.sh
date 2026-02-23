#!/bin/bash
set +e
echo "=== Reboot All Hosts ==="
echo ""
read -p "Are you sure you want to reboot ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Rebooting..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S reboot' 2>/dev/null || true
done
echo ""
echo "Reboot command sent to all hosts."
