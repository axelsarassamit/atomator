#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
run_host() {
    remote_exec "$1" 'set -e; hostname; uptime; free -h; df -h /; systemctl --failed --no-pager'
}
fleet_run run_host
