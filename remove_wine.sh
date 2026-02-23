#!/bin/bash
set +e
echo "=== Remove Wine ==="
echo "Removes Wine and cleans up config directories."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing Wine..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y wine wine64 wine32 winetricks wine-stable 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        rm -rf /home/*/.wine 2>/dev/null || true
        echo \"Wine removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
