#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Simplenote ==="
echo "Installs Simplenote note-taking app via snap."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Simplenote..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        if command -v snap &>/dev/null; then
            snap install simplenote 2>/dev/null && echo \"Simplenote installed via snap\" || echo \"snap install failed\"
        else
            DEBIAN_FRONTEND=noninteractive apt-get install -y snapd 2>/dev/null || true
            snap install simplenote 2>/dev/null && echo \"Simplenote installed via snap\" || echo \"snap install failed\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
