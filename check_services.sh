#!/bin/bash
set +e
echo "=== Check Services ==="
echo "Shows status of important services on all hosts."
echo ""
SERVICES="ssh NetworkManager cron rsyslog"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "--- [$host] ---"
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        "for svc in $SERVICES; do
            STATUS=\$(systemctl is-active \$svc 2>/dev/null || echo 'not found')
            if [ \"\$STATUS\" = 'active' ]; then echo \"  [OK]   \$svc\"; else echo \"  [FAIL] \$svc (\$STATUS)\"; fi
        done" 2>/dev/null || echo "  Could not connect"
    echo ""
done
echo "Done."
