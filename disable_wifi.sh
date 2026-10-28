#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Disable WiFi ==="
echo "Permanently disables WiFi on all hosts via rfkill and NetworkManager."
echo ""
LOCAL_SCRIPT="$ATOMATOR_RUN_DIR/payload.sh"
REMOTE_SCRIPT="/tmp/_disable_wifi.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
nmcli radio wifi off 2>/dev/null || true
rfkill block wifi 2>/dev/null || true
for iface in $(nmcli -t -f DEVICE,TYPE device | grep wifi | cut -d: -f1); do
    nmcli device disconnect "$iface" 2>/dev/null || true
done
mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/disable-wifi.conf << NMCONF
[device-wifi]
wifi.scan-rand-mac-address=no
managed=0
NMCONF
cat > /etc/modprobe.d/disable-wifi.conf << MODCONF
blacklist ath9k
blacklist ath9k_htc
blacklist rt2800usb
blacklist iwlwifi
blacklist iwldvm
blacklist iwlmvm
blacklist rtl8xxxu
blacklist brcmfmac
MODCONF
systemctl restart NetworkManager 2>/dev/null || true
echo "WiFi disabled permanently"
SCRIPT
run_host() {
    local host="$1"
    echo "[$host] Disabling WiFi..."
        remote_script "$host" "$LOCAL_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done."
