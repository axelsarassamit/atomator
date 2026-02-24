#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Run Custom Command ==="
echo "Execute any command on all hosts."
echo ""
read -p "Command (runs as root): " CMD
if [ -z "$CMD" ]; then echo "No command entered."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c '$CMD'" 2>&1 || true
    echo ""
done
echo "Done."
