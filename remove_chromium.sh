#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Remove Chromium ==="
echo "Removes Chromium browser from all hosts."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Removing Chromium..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        DEBIAN_FRONTEND=noninteractive apt-get remove --purge -y chromium-browser chromium
        apt-get autoremove -y
        rm -f /home/*/Desktop/chromium*.desktop 2>/dev/null || true
        echo \"Chromium removed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
