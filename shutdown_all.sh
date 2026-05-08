#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Shutdown All Hosts ==="
echo ""
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
echo "This will shutdown $TOTAL hosts."
read -p "Are you sure you want to SHUTDOWN ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in "${HOSTS[@]}"; do
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S shutdown -h now' &>/dev/null &
done
wait
echo "Shutdown command sent to $TOTAL hosts."
