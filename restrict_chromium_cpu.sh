#!/bin/bash
set +e
echo "=== Restrict Chromium CPU ==="
echo "Limits Chromium to 50% CPU using cpulimit systemd service."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting up CPU limiter..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y cpulimit 2>/dev/null || true
        cat > /etc/systemd/system/chromium-cpu-limit.service << SERVICE
[Unit]
Description=Chromium CPU Limiter
After=multi-user.target
[Service]
Type=simple
ExecStart=/bin/bash -c \"while true; do for pid in \\\$(pgrep -f chromium); do cpulimit -p \\\$pid -l 50 -z 2>/dev/null & done; sleep 10; done\"
Restart=always
[Install]
WantedBy=multi-user.target
SERVICE
        systemctl daemon-reload
        systemctl enable chromium-cpu-limit.service
        systemctl start chromium-cpu-limit.service
        echo \"Chromium limited to 50% CPU\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
