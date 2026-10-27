#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Update & Remove Old Kernels ==="
echo "Updates all systems and purges old kernel packages to free disk space."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Updating + purging old kernels..."
    SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge && apt-get autoclean -y"' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
