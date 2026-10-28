#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -p 'HTTPS URL to test from each host: ' URL || exit 0
[[ "$URL" == https://* && "$URL" != *$'\n'* ]] || { echo 'Enter an HTTPS URL.' >&2; exit 64; }
run_host() { remote_exec "$1" "curl --fail --silent --show-error --location --max-time 20 --output /dev/null -- $(shell_quote "$URL")"; }
fleet_run run_host
