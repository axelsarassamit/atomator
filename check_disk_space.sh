#!/bin/bash
set +e
echo "=== Check Disk Space ==="
echo "Shows disk usage on all hosts. Warns if over 80%."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo "$(hostname)|$(df -h / | awk "NR==2{print \$5}" | tr -d "%")|$(df -h / | awk "NR==2{print \$2}")|$(df -h / | awk "NR==2{print \$4}")"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); USAGE=$(echo "$RESULT" | cut -d'|' -f2)
        TOTAL=$(echo "$RESULT" | cut -d'|' -f3); FREE=$(echo "$RESULT" | cut -d'|' -f4)
        if [ "$USAGE" -ge 90 ] 2>/dev/null; then
            echo -e "  \033[0;31m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  ** CRITICAL **"
        elif [ "$USAGE" -ge 80 ] 2>/dev/null; then
            echo -e "  \033[1;33m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free  * WARNING *"
        else
            echo -e "  \033[0;32m[${USAGE}%]\033[0m $host ($HNAME) - ${TOTAL} total, ${FREE} free"
        fi
    else
        echo -e "  \033[0;31m[----]\033[0m $host - Could not connect"
    fi
done
echo ""
echo "Done."
