#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Firefox ==="
echo "Installs Firefox and creates a desktop shortcut."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Firefox..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y firefox 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr 2>/dev/null || true
        for user_home in /home/*; do
            user=\$(basename \"\$user_home\")
            if [ -d \"\$user_home/Desktop\" ]; then
                cp /usr/share/applications/firefox*.desktop \"\$user_home/Desktop/\" 2>/dev/null || true
                chmod +x \"\$user_home/Desktop/firefox\"*.desktop 2>/dev/null || true
                chown \"\$user:\$user\" \"\$user_home/Desktop/firefox\"*.desktop 2>/dev/null || true
            fi
        done
        echo \"Firefox installed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
