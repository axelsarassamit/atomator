#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Remove Google Chrome ==="
echo "Removes Google Chrome from all hosts."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Removing Chrome..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y google-chrome-stable
        apt-get autoremove -y
        rm -f /home/*/Desktop/google-chrome*.desktop 2>/dev/null || true
        echo \"Google Chrome removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
