#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Google Chrome ==="
echo "Downloads and installs Google Chrome from Google's repository."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Chrome..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        wget -q -O /tmp/google-chrome.deb \"https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb\" 2>/dev/null
        if [ -f /tmp/google-chrome.deb ]; then
            DEBIAN_FRONTEND=noninteractive dpkg -i /tmp/google-chrome.deb 2>/dev/null || true
            DEBIAN_FRONTEND=noninteractive apt-get install -f -y 2>/dev/null || true
            rm -f /tmp/google-chrome.deb
            echo \"Google Chrome installed\"
        else
            echo \"Download failed\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
