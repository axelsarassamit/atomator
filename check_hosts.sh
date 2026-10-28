#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Check Host Status ==="
echo "Pings every host and shows hostname."
echo ""
ONLINE=0; OFFLINE=0; TOTAL=0
for host in "${ATOMATOR_HOSTS[@]}"; do
    TOTAL=$((TOTAL + 1))
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        HNAME=$(remote_exec "$host" 'hostname' 2>/dev/null)
        [ -z "$HNAME" ] && HNAME="?"
        echo -e "  \033[0;32m[ONLINE]\033[0m  $host  ($HNAME)"
        ONLINE=$((ONLINE + 1))
    else
        runtime_record "$host" 1
        echo -e "  \033[0;31m[OFFLINE]\033[0m $host"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo ""
echo "Total: $TOTAL | Online: $ONLINE | Offline: $OFFLINE"
