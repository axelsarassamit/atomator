#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Install Firefox ==="
echo "Installs Firefox and creates a desktop shortcut."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Installing Firefox..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        DEBIAN_FRONTEND=noninteractive apt-get install -y firefox 2>/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y firefox-esr
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
}
fleet_run run_host
echo ""
echo "Done."
