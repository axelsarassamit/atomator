#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Lock Network Settings ==="
echo "Requires sudo password to change network settings (polkit rule)."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Locking network..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        mkdir -p /etc/polkit-1/localauthority/50-local.d
        cat > /etc/polkit-1/localauthority/50-local.d/restrict-network.pkla << POLKIT
[Restrict Network Manager]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.*
ResultAny=auth_admin
ResultInactive=auth_admin
ResultActive=auth_admin
POLKIT
        echo \"Network locked\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
