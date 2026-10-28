#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Lock Network Settings ==="
echo "Requires sudo password to change network settings (polkit rule)."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Locking network..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        mkdir -p /etc/polkit-1/localauthority/50-local.d
        cat > /etc/polkit-1/localauthority/50-local.d/restrict-network.pkla << POLKIT
[Restrict Network Manager]
Identity=unix-user:*
Action=org.freedesktop.NetworkManager.*
ResultAny=auth_admin
ResultInactive=auth_admin
ResultActive=auth_admin
POLKIT
        echo \"Network locked\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
