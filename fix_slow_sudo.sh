#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Slow Sudo ==="
echo "Adds hostname to /etc/hosts so sudo doesn't wait for DNS lookup."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Fixing..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        HNAME=\$(hostname)
        if grep -q \"\$HNAME\" /etc/hosts 2>/dev/null; then
            echo \"Hostname \$HNAME already in /etc/hosts - OK\"
        else
            echo \"127.0.1.1 \$HNAME\" >> /etc/hosts
            echo \"Added \$HNAME to /etc/hosts\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done. Sudo should be fast now."
