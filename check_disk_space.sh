#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Disk Space ==="
echo "Shows disk usage on all hosts. Warns if over 80%."
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="disk_space_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Disk Space" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tUsage%%\tTotal\tUsed\tFree\tStatus\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(SSHPASS="${SSH_PASSWORD:?Set SSH_PASSWORD}" sshpass -e ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo "$(hostname)|$(df -h / | awk "NR==2{print \$5}" | tr -d "%")|$(df -h / | awk "NR==2{print \$2}")|$(df -h / | awk "NR==2{print \$3}")|$(df -h / | awk "NR==2{print \$4}")"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); USAGE=$(echo "$RESULT" | cut -d'|' -f2)
        TOTAL=$(echo "$RESULT" | cut -d'|' -f3); USED=$(echo "$RESULT" | cut -d'|' -f4); FREE=$(echo "$RESULT" | cut -d'|' -f5)
        if [ "$USAGE" -ge 90 ] 2>/dev/null; then
            STATUS="CRITICAL"
            echo -e "  \033[0;31m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **"
        elif [ "$USAGE" -ge 80 ] 2>/dev/null; then
            STATUS="WARNING"
            echo -e "  \033[1;33m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *"
        else
            STATUS="OK"
            echo -e "  \033[0;32m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free"
        fi
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$USAGE" "$TOTAL" "$USED" "$FREE" "$STATUS" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[----]\033[0m $host - Could not connect"
        printf "%s\t-\t-\t-\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
