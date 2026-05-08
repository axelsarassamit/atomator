#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Disk Space ==="
echo "Shows disk usage on all hosts. Warns if over 80%."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="disk_space_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Report: Disk Space" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $TOTAL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tUsage%%\tTotal\tUsed\tFree\tStatus\n" >> "$OUTPUT_FILE"

check_host() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(df -h / | awk "NR==2{print \$5}" | tr -d "%")|$(df -h / | awk "NR==2{print \$2}")|$(df -h / | awk "NR==2{print \$3}")|$(df -h / | awk "NR==2{print \$4}")"' 2>/dev/null)
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
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); USAGE=$(echo "$RESULT" | cut -d'|' -f2)
        DTOTAL=$(echo "$RESULT" | cut -d'|' -f3); USED=$(echo "$RESULT" | cut -d'|' -f4); FREE=$(echo "$RESULT" | cut -d'|' -f5)
        if [ "$USAGE" -ge 90 ] 2>/dev/null; then
            STATUS="CRITICAL"
            echo -e "  \033[0;31m[${USAGE}%]\033[0m ${HOSTS[$i]} ($HNAME) - ${DTOTAL} total, ${FREE} free  ** CRITICAL **"
        elif [ "$USAGE" -ge 80 ] 2>/dev/null; then
            STATUS="WARNING"
            echo -e "  \033[1;33m[${USAGE}%]\033[0m ${HOSTS[$i]} ($HNAME) - ${DTOTAL} total, ${FREE} free  * WARNING *"
        else
            STATUS="OK"
            echo -e "  \033[0;32m[${USAGE}%]\033[0m ${HOSTS[$i]} ($HNAME) - ${DTOTAL} total, ${FREE} free"
        fi
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "${HOSTS[$i]}" "$HNAME" "$USAGE" "$DTOTAL" "$USED" "$FREE" "$STATUS" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[----]\033[0m ${HOSTS[$i]} - Could not connect"
        printf "%s\t-\t-\t-\t-\t-\tOFFLINE\n" "${HOSTS[$i]}" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "Total: $TOTAL hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE | ${ELAPSED}s"
echo "Saved to: $OUTPUT_FILE"
