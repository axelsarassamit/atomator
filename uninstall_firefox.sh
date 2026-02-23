#!/bin/bash
set +e
echo "=== Uninstall Firefox ==="
echo "Removes Firefox. User profiles (~/.mozilla) are kept."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing Firefox..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y firefox firefox-esr firefox-locale-* 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        rm -f /home/*/Desktop/firefox*.desktop 2>/dev/null || true
        echo \"Firefox removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
