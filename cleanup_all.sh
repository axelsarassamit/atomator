#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== System Cleanup ==="
echo "Cleans APT cache, old logs, temp files and trash on all hosts."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Cleaning up..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        apt-get clean -y
        apt-get autoclean -y
        apt-get autoremove -y
        journalctl --vacuum-time=7d 2>/dev/null || true
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/files/* 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/info/* 2>/dev/null || true
        rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
        echo \"Done\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
