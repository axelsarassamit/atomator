#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -p 'Command (runs as root): ' CMD || exit 0
[[ -n "$CMD" ]] || exit 0
printf '%s\n' "$CMD" > "$ATOMATOR_RUN_DIR/payload.sh"
run_host() { remote_script "$1" "$ATOMATOR_RUN_DIR/payload.sh"; }
fleet_run run_host
