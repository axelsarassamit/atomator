#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect MAC Addresses ==="
echo "Gathers MAC addresses from all hosts for Wake-on-LAN."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="mac_addresses.txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

collect_mac() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'IFACE=$(ip route | grep default | awk "{print \$5}" | head -1); if [ -n "$IFACE" ]; then MAC=$(cat /sys/class/net/$IFACE/address 2>/dev/null); HOSTNAME=$(hostname); echo "$MAC|$HOSTNAME"; fi' 2>/dev/null)
    if [ -n "$result" ]; then
        echo "OK|$result" > "$TMPDIR/$idx"
    else
        echo "FAIL" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    collect_mac "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.2; done
done
wait

> "$OUTPUT_FILE"
for i in "${!HOSTS[@]}"; do
    if [ -f "$TMPDIR/$i" ] && grep -q "OK" "$TMPDIR/$i"; then
        DATA=$(cut -d'|' -f2- "$TMPDIR/$i")
        MAC=$(echo "$DATA" | cut -d'|' -f1)
        HNAME=$(echo "$DATA" | cut -d'|' -f2)
        echo "${HOSTS[$i]} | $MAC | $HNAME" >> "$OUTPUT_FILE"
        echo "  ${HOSTS[$i]} | $MAC | $HNAME"
    else
        echo "  ${HOSTS[$i]} | FAILED"
    fi
done

ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Saved to: $OUTPUT_FILE (${ELAPSED}s)"
