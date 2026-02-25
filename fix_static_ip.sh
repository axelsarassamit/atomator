#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Static IP ==="
echo "Sets static IP based on gateway + hostname."
echo "IP = gateway first 3 octets + last digits of hostname."
echo "Example: gateway 192.168.1.1 + hostname BKSAL058 = 192.168.1.58/24"
echo ""
echo "DNS for static IP:"
echo "  1. Keep current DNS from each host"
echo "  2. Cloudflare + Google + Quad9 (1.1.1.1 8.8.8.8 9.9.9.9)"
echo "  3. Enter custom DNS servers"
echo ""
read -p "Choice [1-3] (default 1): " dns_choice
DNS_OVERRIDE=""
case $dns_choice in
    2)
        DNS_OVERRIDE="1.1.1.1 8.8.8.8 9.9.9.9"
        echo ""
        echo "Using: $DNS_OVERRIDE"
        ;;
    3)
        echo ""
        read -p "Enter DNS servers (space-separated, e.g. 10.0.0.5 1.1.1.1): " CUSTOM_DNS
        if [ -z "$CUSTOM_DNS" ]; then echo "No DNS entered. Cancelled."; exit 1; fi
        DNS_OVERRIDE="$CUSTOM_DNS"
        echo "Using: $DNS_OVERRIDE"
        ;;
    *)
        echo ""
        echo "Keeping current DNS from each host (fallback: 1.1.1.1 8.8.8.8 9.9.9.9)"
        ;;
esac
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting static IP..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEV=\$(nmcli -t -f DEVICE,TYPE device | grep ethernet | head -1 | cut -d: -f1)
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -z \"\$CON_NAME\" ] || [ -z \"\$DEV\" ]; then echo \"No ethernet found\"; exit 1; fi
        GATEWAY=\$(nmcli -t -f IP4.GATEWAY device show \"\$DEV\" | head -1 | cut -d: -f2)
        if [ -z \"\$GATEWAY\" ]; then echo \"Could not detect gateway\"; exit 1; fi
        BASE=\$(echo \"\$GATEWAY\" | cut -d. -f1-3)
        HNAME=\$(hostname)
        DIGITS=\$(echo \"\$HNAME\" | grep -o \"[0-9]*\\\$\")
        if [ -z \"\$DIGITS\" ]; then echo \"ERROR: hostname \$HNAME has no trailing digits\"; exit 1; fi
        LAST_OCTET=\$(echo \"\$DIGITS\" | sed \"s/^0*//\")
        [ -z \"\$LAST_OCTET\" ] && LAST_OCTET=0
        if [ \"\$LAST_OCTET\" -gt 254 ]; then echo \"ERROR: hostname digits \$DIGITS give octet \$LAST_OCTET (>254)\"; exit 1; fi
        NEW_IP=\"\${BASE}.\${LAST_OCTET}/24\"
        if [ -n \"'"$DNS_OVERRIDE"'\" ]; then
            DNS=\"'"$DNS_OVERRIDE"'\"
        else
            DNS=\$(nmcli -t -f IP4.DNS device show \"\$DEV\" 2>/dev/null | head -1 | cut -d: -f2)
            [ -z \"\$DNS\" ] && DNS=\"1.1.1.1 8.8.8.8 9.9.9.9\"
        fi
        nmcli con mod \"\$CON_NAME\" ipv4.method manual ipv4.addresses \"\$NEW_IP\" ipv4.gateway \"\$GATEWAY\" ipv4.dns \"\$DNS\" ipv4.ignore-auto-dns yes
        nmcli con up \"\$CON_NAME\" 2>/dev/null || true
        echo \"Static IP: \$NEW_IP gw \$GATEWAY dns \$DNS (hostname: \$HNAME)\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
