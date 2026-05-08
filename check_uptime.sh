#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Uptime ==="
echo "Shows how long each host has been running."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="uptime_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Report: Uptime" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $TOTAL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tUptime\tSince\n" >> "$OUTPUT_FILE"

check_host() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(uptime -p 2>/dev/null || echo N/A)|$(uptime -s 2>/dev/null || echo N/A)"' 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result" > "$TMPDIR/$idx"
    else
        echo "" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    check_host "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.2; done
done
wait

ONLINE=0; OFFLINE=0
for i in "${!HOSTS[@]}"; do
    RESULT=""
    [ -f "$TMPDIR/$i" ] && RESULT=$(cat "$TMPDIR/$i")
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); UP=$(echo "$RESULT" | cut -d'|' -f2); SINCE=$(echo "$RESULT" | cut -d'|' -f3)
        echo -e "  \033[0;32m${HOSTS[$i]}\033[0m ($HNAME) - $UP (since $SINCE)"
        printf "%s\t%s\t%s\t%s\n" "${HOSTS[$i]}" "$HNAME" "$UP" "$SINCE" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m${HOSTS[$i]}\033[0m - OFFLINE"
        printf "%s\t-\t-\tOFFLINE\n" "${HOSTS[$i]}" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "Total: $TOTAL hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE | ${ELAPSED}s"
echo "Saved to: $OUTPUT_FILE"
