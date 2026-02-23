#!/bin/bash
set +e
echo "=== Check Services ==="
echo "Shows status of important services on all hosts."
echo ""
OUTPUT_FILE="services_$(date +%Y%m%d_%H%M%S).txt"
echo "Services Report - $(date)" > "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
SERVICES="ssh NetworkManager cron rsyslog"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    echo "--- [$host] ---" >> "$OUTPUT_FILE"
    RESULT=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        "for svc in $SERVICES; do
            STATUS=\$(systemctl is-active \$svc 2>/dev/null || echo 'not found')
            if [ \"\$STATUS\" = 'active' ]; then echo \"  [OK]   \$svc\"; else echo \"  [FAIL] \$svc (\$STATUS)\"; fi
        done" 2>/dev/null)
    if [ -n "$RESULT" ]; then
        echo "$RESULT"
        echo "$RESULT" >> "$OUTPUT_FILE"
    else
        echo "  Could not connect"
        echo "  Could not connect" >> "$OUTPUT_FILE"
    fi
    echo ""
    echo "" >> "$OUTPUT_FILE"
done
echo "Saved to: $OUTPUT_FILE"
