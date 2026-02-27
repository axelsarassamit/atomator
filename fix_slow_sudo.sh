#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Slow Sudo ==="
echo "Fixes hostname resolution and sudo config to eliminate delays."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Fixing..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        HNAME=\$(hostname)

        # 1. Ensure 127.0.1.1 line has correct hostname
        if grep -q \"^127\\.0\\.1\\.1\" /etc/hosts 2>/dev/null; then
            if grep -q \"^127\\.0\\.1\\.1.*\b\$HNAME\b\" /etc/hosts 2>/dev/null; then
                echo \"127.0.1.1 already has \$HNAME - OK\"
            else
                sed -i \"s/^127\\.0\\.1\\.1.*/127.0.1.1\t\$HNAME/\" /etc/hosts
                echo \"Updated 127.0.1.1 line with \$HNAME\"
            fi
        else
            echo -e \"127.0.1.1\t\$HNAME\" >> /etc/hosts
            echo \"Added 127.0.1.1 \$HNAME to /etc/hosts\"
        fi

        # 2. Ensure localhost is correct
        if ! grep -q \"^127\\.0\\.0\\.1.*localhost\" /etc/hosts 2>/dev/null; then
            sed -i \"1i 127.0.0.1\tlocalhost\" /etc/hosts
            echo \"Added localhost entry\"
        fi

        # 3. Fix nsswitch.conf - ensure files comes before dns
        if grep -q \"^hosts:\" /etc/nsswitch.conf 2>/dev/null; then
            CURRENT=\$(grep \"^hosts:\" /etc/nsswitch.conf)
            if echo \"\$CURRENT\" | grep -q \"dns.*files\"; then
                sed -i \"s/^hosts:.*/hosts:          files mdns4_minimal [NOTFOUND=return] dns/\" /etc/nsswitch.conf
                echo \"Fixed nsswitch.conf: files now before dns\"
            else
                echo \"nsswitch.conf order OK\"
            fi
        fi

        # 4. Verify fix
        RESULT=\$(getent hosts \$HNAME 2>/dev/null)
        if [ -n \"\$RESULT\" ]; then
            echo \"Verified: \$HNAME resolves to \$RESULT\"
        else
            echo \"WARNING: \$HNAME still not resolving\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done. Sudo should be fast now."
