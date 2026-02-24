#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Uptime ==="
echo "Shows how long each host has been running."
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="uptime_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Uptime" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tUptime\tSince\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(uptime -p 2>/dev/null || echo N/A)|$(uptime -s 2>/dev/null || echo N/A)"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); UP=$(echo "$RESULT" | cut -d'|' -f2); SINCE=$(echo "$RESULT" | cut -d'|' -f3)
        echo -e "  \033[0;32m$host\033[0m ($HNAME) - $UP (since $SINCE)"
        printf "%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$UP" "$SINCE" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m$host\033[0m - OFFLINE"
        printf "%s\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
