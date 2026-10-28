#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Reboot All Hosts ==="
echo ""
read -p "Are you sure you want to reboot ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
run_host() {
    local host="$1"
    echo "[$host] Rebooting..."
    remote_exec "$host" \
        'sudo -n reboot'
}
fleet_run run_host
echo ""
echo "Reboot requests processed. See per-host results."
