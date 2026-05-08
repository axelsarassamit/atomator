#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect RAM Info ==="
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="ram_info_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Report: RAM Info" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $TOTAL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tTotal\tUsed\tFree\n" >> "$OUTPUT_FILE"

collect_host() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(free -h | awk "/Mem:/{print \$2}")|$(free -h | awk "/Mem:/{print \$3}")|$(free -h | awk "/Mem:/{print \$4}")|$(free -m | awk "/Mem:/{print \$2}")"' 2>/dev/null)
    if [ -n "$result" ]; then
        echo "$result" > "$TMPDIR/$idx"
    else
        echo "" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    collect_host "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.2; done
done
wait

ONLINE=0; OFFLINE=0; TOTAL_RAM=0
for i in "${!HOSTS[@]}"; do
    RESULT=""
    [ -f "$TMPDIR/$i" ] && RESULT=$(cat "$TMPDIR/$i")
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); TOT=$(echo "$RESULT" | cut -d'|' -f2)
        USED=$(echo "$RESULT" | cut -d'|' -f3); FREE=$(echo "$RESULT" | cut -d'|' -f4)
        RAM_MB=$(echo "$RESULT" | cut -d'|' -f5)
        echo -e "  \033[0;32mOK\033[0m ${HOSTS[$i]} ($HNAME) | Total: $TOT | Used: $USED | Free: $FREE"
        printf "%s\t%s\t%s\t%s\t%s\n" "${HOSTS[$i]}" "$HNAME" "$TOT" "$USED" "$FREE" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
        if [ -n "$RAM_MB" ] && [ "$RAM_MB" -gt 0 ] 2>/dev/null; then
            TOTAL_RAM=$((TOTAL_RAM + RAM_MB))
        fi
    else
        echo -e "  \033[0;31mFAILED\033[0m ${HOSTS[$i]}"
        printf "%s\t-\t-\t-\tOFFLINE\n" "${HOSTS[$i]}" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done

echo "" >> "$OUTPUT_FILE"
SUMMARY="Total: $TOTAL hosts | Online: $ONLINE | Offline: $OFFLINE"
if [ $ONLINE -gt 0 ]; then
    SUMMARY="$SUMMARY | Total RAM: $((TOTAL_RAM / 1024)) GB | Average: $((TOTAL_RAM / ONLINE / 1024)) GB/host"
fi
echo "$SUMMARY" >> "$OUTPUT_FILE"
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "$SUMMARY | ${ELAPSED}s"
echo "Saved to: $OUTPUT_FILE"
