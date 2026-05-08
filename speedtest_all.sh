#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Speed Test All Hosts ==="
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-3}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="speedtest_results_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Report: Speed Test" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $TOTAL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tPing_ms\tDownload_Mbps\tUpload_Mbps\n" >> "$OUTPUT_FILE"

run_test() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        which speedtest-cli >/dev/null 2>&1 || apt-get install -y speedtest-cli >/dev/null 2>&1
        HNAME=\$(hostname)
        RAW=\$(speedtest-cli --simple 2>/dev/null)
        if [ -n \"\$RAW\" ]; then
            PING=\$(echo \"\$RAW\" | grep \"Ping:\" | awk \"{print \\\$2}\")
            DOWN=\$(echo \"\$RAW\" | grep \"Download:\" | awk \"{print \\\$2}\")
            UP=\$(echo \"\$RAW\" | grep \"Upload:\" | awk \"{print \\\$2}\")
            echo \"\$HNAME|\$PING|\$DOWN|\$UP\"
        else
            echo \"\$HNAME|FAILED\"
        fi
    "' 2>/dev/null)
    echo "$result" > "$TMPDIR/$idx"
}

echo "Running speed tests ($MAX_JOBS parallel)..."
echo ""
for i in "${!HOSTS[@]}"; do
    run_test "${HOSTS[$i]}" "$i" &
    echo "[$((i+1))/$TOTAL] ${HOSTS[$i]} - started"
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 1; done
done
wait

echo ""
ONLINE=0; OFFLINE=0
for i in "${!HOSTS[@]}"; do
    RESULT=""
    [ -f "$TMPDIR/$i" ] && RESULT=$(cat "$TMPDIR/$i")
    if [ -n "$RESULT" ] && ! echo "$RESULT" | grep -q "FAILED"; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        PING=$(echo "$RESULT" | cut -d'|' -f2)
        DOWN=$(echo "$RESULT" | cut -d'|' -f3)
        UP=$(echo "$RESULT" | cut -d'|' -f4)
        echo -e "  \033[0;32m[OK]\033[0m ${HOSTS[$i]} ($HNAME) | Ping: ${PING}ms | Down: ${DOWN}Mbps | Up: ${UP}Mbps"
        printf "%s\t%s\t%s\t%s\t%s\n" "${HOSTS[$i]}" "$HNAME" "$PING" "$DOWN" "$UP" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    elif [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        echo -e "  \033[1;33m[FAIL]\033[0m ${HOSTS[$i]} ($HNAME) - speedtest failed"
        printf "%s\t%s\t-\t-\t-\n" "${HOSTS[$i]}" "$HNAME" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[OFF]\033[0m  ${HOSTS[$i]}"
        printf "%s\t-\t-\t-\tOFFLINE\n" "${HOSTS[$i]}" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "Total: $TOTAL hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE | ${ELAPSED}s"
echo "Saved to: $OUTPUT_FILE"
