#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Change DNS Servers ==="
echo ""
echo "DNS servers to set:"
echo "  1. Cloudflare + Google + Quad9 (1.1.1.1 8.8.8.8 9.9.9.9)"
echo "  2. Enter custom DNS servers"
echo ""
read -p "Choice [1-2] (default 1): " dns_choice
case $dns_choice in
    2)
        echo ""
        read -p "Enter DNS servers (space-separated, e.g. 192.0.2.1 1.1.1.1): " CUSTOM_DNS
        if [ -z "$CUSTOM_DNS" ]; then echo "No DNS entered. Cancelled."; exit 1; fi
        DNS_SERVERS="$CUSTOM_DNS"
        ;;
    *)
        DNS_SERVERS="1.1.1.1 8.8.8.8 9.9.9.9"
        ;;
esac
python3 "$ATOMATOR_ROOT/lib/settings.py" dns "$DNS_SERVERS" || exit 64
echo ""
echo "Setting DNS to: $DNS_SERVERS"
echo ""
run_host() {
    local host="$1"
    echo "[$host] Changing DNS..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -n \"\$CON_NAME\" ]; then
            nmcli con mod \"\$CON_NAME\" ipv4.dns \"'"$DNS_SERVERS"'\"
            nmcli con mod \"\$CON_NAME\" ipv4.ignore-auto-dns yes
            nmcli con up \"\$CON_NAME\" 2>/dev/null || true
            echo \"DNS set to: '"$DNS_SERVERS"'\"
        else
            echo \"No active ethernet connection\"
        fi
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done."
