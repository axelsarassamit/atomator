#!/bin/bash
set +e
echo "=== Check Uptime ==="
echo "Shows how long each host has been running."
echo ""
OUTPUT_FILE="uptime_$(date +%Y%m%d_%H%M%S).txt"
echo "Uptime Report - $(date)" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo "$(hostname)|$(uptime -p)|$(uptime -s)"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); UP=$(echo "$RESULT" | cut -d'|' -f2); SINCE=$(echo "$RESULT" | cut -d'|' -f3)
        echo "  $host ($HNAME) - $UP (since $SINCE)"
        echo "$host ($HNAME) - $UP (since $SINCE)" >> "$OUTPUT_FILE"
    else
        echo -e "  $host - \033[0;31mOFFLINE\033[0m"
        echo "$host - OFFLINE" >> "$OUTPUT_FILE"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
