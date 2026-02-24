#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Disable WiFi ==="
echo "Permanently disables WiFi on all hosts via rfkill and NetworkManager."
echo ""
LOCAL_SCRIPT="/tmp/_disable_wifi.sh"
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
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Disabling WiFi..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done."
