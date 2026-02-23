#!/bin/bash
set +e
echo "=== Wake-on-LAN ==="
echo "Sends WOL magic packets to wake up all computers."
echo ""
MAC_FILE="mac_addresses.txt"
if [ ! -f "$MAC_FILE" ]; then
    echo "Error: $MAC_FILE not found! Run collect_mac_addresses.sh first."
    exit 1
fi
while IFS='|' read -r ip mac hostname; do
    ip=$(echo "$ip" | xargs); mac=$(echo "$mac" | xargs); hostname=$(echo "$hostname" | xargs)
    if [ -z "$mac" ] || echo "$ip" | grep -q "^#"; then continue; fi
    echo "  Waking $ip ($hostname) - MAC: $mac"
    for i in 1 2 3; do wakeonlan "$mac" 2>/dev/null || true; done
done < "$MAC_FILE"
echo ""
echo "WOL packets sent (3x per host). Wait 30-60s then check status."
