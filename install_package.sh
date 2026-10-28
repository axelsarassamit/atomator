#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -p 'APT package names (space separated): ' packages || exit 0
read -r -a PACKAGES <<< "$packages"
((${#PACKAGES[@]})) || exit 0
for package in "${PACKAGES[@]}"; do
    [[ "$package" =~ ^[a-z0-9][a-z0-9+.-]*(:[a-z0-9]+)?$ ]] || { echo "Invalid package: $package" >&2; exit 64; }
done
printf '%s\n' 'export DEBIAN_FRONTEND=noninteractive' 'apt-get update -qq' 'apt-get install -y -- "$@"' > "$ATOMATOR_RUN_DIR/payload.sh"
run_host() { remote_script "$1" "$ATOMATOR_RUN_DIR/payload.sh" "${PACKAGES[@]}"; }
fleet_run run_host
