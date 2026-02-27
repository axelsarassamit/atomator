#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Hostname Display ==="
echo "Repairs conky hostname display: kills all instances, removes old"
echo "configs, recreates clean config, and starts conky immediately."
echo ""
LOCAL_SCRIPT="/tmp/_fix_hostname_display.sh"
REMOTE_SCRIPT="/tmp/_fix_hostname_display.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
# Install conky if missing
if ! command -v conky &>/dev/null; then
    echo "Conky not found, installing..."
    DEBIAN_FRONTEND=noninteractive apt-get install -y conky-all 2>/dev/null || true
fi
# Kill ALL conky processes
pkill -f "conky" 2>/dev/null || true
sleep 1
# Make sure they are all dead
killall -9 conky 2>/dev/null || true
sleep 1
HOSTNAME_LABEL=$(hostname)
FIXED=0
for user_home in /home/*; do
    user=$(basename "$user_home")
    id "$user" &>/dev/null || continue
    # Remove ALL old conky configs and autostart files
    rm -f "$user_home/.config/conky_hostname.conf" 2>/dev/null
    rm -f "$user_home/.conkyrc" 2>/dev/null
    rm -f "$user_home/.config/conky/"*.conf 2>/dev/null
    rm -f "$user_home/.config/autostart/conky"*.desktop 2>/dev/null
    # Create clean config (pseudo-transparency, no black background)
    mkdir -p "$user_home/.config"
    cat > "$user_home/.config/conky_hostname.conf" << CONKYCONF
conky.config = {
    alignment = 'bottom_right',
    background = true,
    double_buffer = true,
    font = 'DejaVu Sans:bold:size=14',
    gap_x = 20,
    gap_y = 40,
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    draw_shads = false,
    update_interval = 60,
    use_xft = true,
};
conky.text = [[
\${color white}$HOSTNAME_LABEL
]];
CONKYCONF
    chown "$user:$user" "$user_home/.config/conky_hostname.conf"
    # Create single autostart entry
    mkdir -p "$user_home/.config/autostart"
    cat > "$user_home/.config/autostart/conky-hostname.desktop" << DESKTOP
[Desktop Entry]
Type=Application
Name=Hostname Display
Exec=bash -c "sleep 5 && conky -c $user_home/.config/conky_hostname.conf"
Hidden=false
X-GNOME-Autostart-enabled=true
DESKTOP
    chown "$user:$user" "$user_home/.config/autostart/conky-hostname.desktop"
    # Start conky now for logged-in users
    if who | grep -q "^$user "; then
        su - "$user" -c "DISPLAY=:0 nohup conky -c $user_home/.config/conky_hostname.conf -d >/dev/null 2>&1 &" 2>/dev/null || true
        sleep 1
    fi
    FIXED=$((FIXED + 1))
done
echo "Fixed $FIXED user(s), hostname: $HOSTNAME_LABEL"
SCRIPT
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Fixing hostname display..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done. Hostname should be visible now (or after next login)."
