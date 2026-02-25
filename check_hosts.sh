#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Host Status ==="
echo "Pings every host and shows hostname."
echo ""
ONLINE=0; OFFLINE=0; TOTAL=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    TOTAL=$((TOTAL + 1))
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        HNAME=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER"@"$host" 'hostname' 2>/dev/null)
        [ -z "$HNAME" ] && HNAME="?"
        echo -e "  \033[0;32m[ONLINE]\033[0m  $host  ($HNAME)"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[OFFLINE]\033[0m $host"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo ""
echo "Total: $TOTAL | Online: $ONLINE | Offline: $OFFLINE"
