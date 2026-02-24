#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect MAC Addresses ==="
echo "Gathers MAC addresses from all hosts for Wake-on-LAN."
echo ""
OUTPUT_FILE="mac_addresses.txt"
> "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    MAC_INFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'IFACE=$(ip route | grep default | awk "{print \$5}" | head -1); if [ -n "$IFACE" ]; then MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null); HOSTNAME=$(hostname); echo "$MAC|$HOSTNAME"; fi' 2>/dev/null) || true
    if [ -n "$MAC_INFO" ]; then
        MAC=$(echo "$MAC_INFO" | cut -d'|' -f1); HNAME=$(echo "$MAC_INFO" | cut -d'|' -f2)
        echo "$host | $MAC | $HNAME" >> "$OUTPUT_FILE"
        echo "  $host | $MAC | $HNAME"
    else
        echo "  $host | FAILED"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
