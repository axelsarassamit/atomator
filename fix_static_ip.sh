#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Static IP ==="
echo "Converts the current DHCP address to a permanent static IP."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting static IP..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEV=\$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -1 | cut -d: -f1)
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -z \"\$CON_NAME\" ] || [ -z \"\$DEV\" ]; then echo \"No ethernet found\"; exit 1; fi
        CURRENT_IP=\$(nmcli -t -f IP4.ADDRESS device show \"\$DEV\" | head -1 | cut -d: -f2)
        GATEWAY=\$(nmcli -t -f IP4.GATEWAY device show \"\$DEV\" | head -1 | cut -d: -f2)
        DNS=\$(nmcli -t -f IP4.DNS device show \"\$DEV\" 2>/dev/null | head -1 | cut -d: -f2)
        [ -z \"\$DNS\" ] && DNS=\"1.1.1.1 8.8.8.8 9.9.9.9\"
        if [ -z \"\$CURRENT_IP\" ]; then echo \"Could not detect IP\"; exit 1; fi
        nmcli con mod \"\$CON_NAME\" ipv4.method manual ipv4.addresses \"\$CURRENT_IP\" ipv4.gateway \"\$GATEWAY\" ipv4.dns \"\$DNS\" ipv4.ignore-auto-dns yes
        nmcli con up \"\$CON_NAME\" 2>/dev/null || true
        echo \"Static IP: \$CURRENT_IP gw \$GATEWAY dns \$DNS\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
