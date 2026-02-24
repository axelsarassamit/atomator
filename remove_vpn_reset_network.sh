#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Remove VPN & Reset Network ==="
echo "Removes all VPN packages/connections and resets to static IP with DNS."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Removing VPN + resetting..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge openvpn wireguard wireguard-tools network-manager-openvpn network-manager-vpnc network-manager-pptp network-manager-l2tp 2>/dev/null || true
        apt-get autoremove -y 2>/dev/null || true
        for conn in \$(nmcli -t -f NAME,TYPE connection show | grep -E \"vpn|wireguard|tun|openvpn\" | cut -d: -f1); do
            nmcli connection delete \"\$conn\" 2>/dev/null || true
        done
        rm -rf /etc/openvpn/* /etc/wireguard/* 2>/dev/null || true
        DEV=\$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -1 | cut -d: -f1)
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -n \"\$CON_NAME\" ] && [ -n \"\$DEV\" ]; then
            CURRENT_IP=\$(nmcli -t -f IP4.ADDRESS device show \"\$DEV\" | head -1 | cut -d: -f2)
            GATEWAY=\$(nmcli -t -f IP4.GATEWAY device show \"\$DEV\" | head -1 | cut -d: -f2)
            DNS=\$(nmcli -t -f IP4.DNS device show \"\$DEV\" 2>/dev/null | head -1 | cut -d: -f2)
            [ -z \"\$DNS\" ] && DNS=\"1.1.1.1 8.8.8.8 9.9.9.9\"
            nmcli con mod \"\$CON_NAME\" ipv4.method manual ipv4.addresses \"\$CURRENT_IP\" ipv4.gateway \"\$GATEWAY\" ipv4.dns \"\$DNS\" ipv4.ignore-auto-dns yes
            nmcli con up \"\$CON_NAME\" 2>/dev/null || true
            echo \"VPN removed. Static IP: \$CURRENT_IP DNS: \$DNS\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
