#!/bin/bash
set +e
echo "=== Check Disk Space ==="
echo "Shows disk usage on all hosts. Warns if over 80%."
echo ""
OUTPUT_FILE="disk_space_$(date +%Y%m%d_%H%M%S).txt"
echo "Disk Space Report - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo "$(hostname)|$(df -h / | awk "NR==2{print \$5}" | tr -d "%")|$(df -h / | awk "NR==2{print \$2}")|$(df -h / | awk "NR==2{print \$4}")"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); USAGE=$(echo "$RESULT" | cut -d'|' -f2)
        TOTAL=$(echo "$RESULT" | cut -d'|' -f3); FREE=$(echo "$RESULT" | cut -d'|' -f4)
        if [ "$USAGE" -ge 90 ] 2>/dev/null; then
            echo -e "  \033[0;31m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **" >> "$OUTPUT_FILE"
        elif [ "$USAGE" -ge 80 ] 2>/dev/null; then
            echo -e "  \033[1;33m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *" >> "$OUTPUT_FILE"
        else
            echo -e "  \033[0;32m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free"
            echo "[${USAGE}%] $host ($HNAME) - ${TOTAL} total, ${FREE} free" >> "$OUTPUT_FILE"
        fi
    else
        echo -e "  \033[0;31m[----]\033[0m $host - Could not connect"
        echo "[----] $host - Could not connect" >> "$OUTPUT_FILE"
    fi
done
echo ""
echo "Saved to: $OUTPUT_FILE"
