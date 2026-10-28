#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Restrict Chromium CPU ==="
echo "Limits Chromium to 50% CPU using cpulimit systemd service."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Setting up CPU limiter..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        DEBIAN_FRONTEND=noninteractive apt-get install -y cpulimit
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
}
fleet_run run_host
echo ""
echo "Done."
