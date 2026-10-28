#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Install Simplenote ==="
echo "Installs Simplenote note-taking app via snap."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Installing Simplenote..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        if command -v snap &>/dev/null; then
            snap install simplenote && echo \"Simplenote installed via snap\"
        else
            DEBIAN_FRONTEND=noninteractive apt-get install -y snapd
            snap install simplenote && echo \"Simplenote installed via snap\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
