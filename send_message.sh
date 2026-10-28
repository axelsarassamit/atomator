#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -p 'Message for logged-in terminal users: ' MESSAGE || exit 0
[[ -n "$MESSAGE" ]] || exit 0
run_host() { printf '%s\n' "$MESSAGE" | remote_input "$1" 'wall'; }
fleet_run run_host
