#!/bin/bash
set +e
echo "=== Check Host Status ==="
echo "Pings every host to see which are online or offline."
echo ""
ONLINE=0; OFFLINE=0; TOTAL=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    TOTAL=$((TOTAL + 1))
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        echo -e "  \033[0;32m[ONLINE]\033[0m  $host"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[OFFLINE]\033[0m $host"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo ""
echo "Total: $TOTAL | Online: $ONLINE | Offline: $OFFLINE"
