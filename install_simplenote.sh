#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Simplenote ==="
echo "Installs Simplenote note-taking app via snap."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Simplenote..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
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
