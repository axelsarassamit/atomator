#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Speed Test All Hosts ==="
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="speedtest_results_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Speed Test" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tPing_ms\tDownload_Mbps\tUpload_Mbps\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo -n "[$host] Testing (takes a moment)... "
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
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
    "' 2>/dev/null) || true
    if [ -n "$RESULT" ] && ! echo "$RESULT" | grep -q "FAILED"; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        PING=$(echo "$RESULT" | cut -d'|' -f2)
        DOWN=$(echo "$RESULT" | cut -d'|' -f3)
        UP=$(echo "$RESULT" | cut -d'|' -f4)
        echo -e "\033[0;32mOK\033[0m - $HNAME | Ping: ${PING}ms | Down: ${DOWN}Mbps | Up: ${UP}Mbps"
        printf "%s\t%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$PING" "$DOWN" "$UP" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    elif [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        echo -e "\033[1;33mFAILED\033[0m - $HNAME (speedtest failed)"
        printf "%s\t%s\t-\t-\t-\n" "$host" "$HNAME" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "\033[0;31mOFFLINE\033[0m"
        printf "%s\t-\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
