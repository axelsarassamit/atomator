#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect RAM Info ==="
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="ram_info_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: RAM Info" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tTotal\tUsed\tFree\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0; TOTAL_RAM=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo -n "[$host] Collecting RAM... "
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(free -h | awk "/Mem:/{print \$2}")|$(free -h | awk "/Mem:/{print \$3}")|$(free -h | awk "/Mem:/{print \$4}")|$(free -m | awk "/Mem:/{print \$2}")"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); TOT=$(echo "$RESULT" | cut -d'|' -f2)
        USED=$(echo "$RESULT" | cut -d'|' -f3); FREE=$(echo "$RESULT" | cut -d'|' -f4)
        RAM_MB=$(echo "$RESULT" | cut -d'|' -f5)
        echo -e "\033[0;32mOK\033[0m - $HNAME | Total: $TOT | Used: $USED | Free: $FREE"
        printf "%s\t%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$TOT" "$USED" "$FREE" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
        if [ -n "$RAM_MB" ] && [ "$RAM_MB" -gt 0 ] 2>/dev/null; then
            TOTAL_RAM=$((TOTAL_RAM + RAM_MB))
        fi
    else
        echo -e "\033[0;31mFAILED\033[0m"
        printf "%s\t-\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
SUMMARY="Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE"
if [ $ONLINE -gt 0 ]; then
    SUMMARY="$SUMMARY | Total RAM: $((TOTAL_RAM / 1024)) GB | Average: $((TOTAL_RAM / ONLINE / 1024)) GB/host"
fi
echo "$SUMMARY" >> "$OUTPUT_FILE"
echo ""
echo "$SUMMARY"
echo "Saved to: $OUTPUT_FILE"
