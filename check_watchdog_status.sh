#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Check Watchdog Status ==="
echo ""
run_host() {
    local host="$1"
    echo "--- [$host] ---"
    remote_exec "$host" \
        'sudo -n /usr/local/bin/watchdog-status.sh 2>/dev/null || echo "Watchdog not installed"' 2>/dev/null || echo "  Could not connect"
    echo ""
}
fleet_run run_host
echo "Done."
