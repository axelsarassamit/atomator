#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
cat > "$ATOMATOR_RUN_DIR/payload.sh" <<'PAYLOAD'
tmp=$(mktemp --suffix=.deb)
trap 'rm -f -- "$tmp"' EXIT
curl --fail --silent --show-error --location --output "$tmp" -- https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
export DEBIAN_FRONTEND=noninteractive
dpkg -i "$tmp" || apt-get install -f -y
dpkg-query -W -f='${Status}' google-chrome-stable | grep -q 'install ok installed'
PAYLOAD
run_host() { remote_script "$1" "$ATOMATOR_RUN_DIR/payload.sh"; }
fleet_run run_host
