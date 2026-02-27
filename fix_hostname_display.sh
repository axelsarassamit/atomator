#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Fix Hostname Display ==="
echo "Repairs conky hostname display: kills stuck processes, recreates"
echo "config and autostart, and starts conky immediately."
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
# Kill any stuck conky processes
pkill -f "conky" 2>/dev/null || true
sleep 1
HOSTNAME_LABEL=$(hostname)
FIXED=0
for user_home in /home/*; do
    user=$(basename "$user_home")
    id "$user" &>/dev/null || continue
    # Recreate config
    mkdir -p "$user_home/.config"
    cat > "$user_home/.config/conky_hostname.conf" << CONKYCONF
conky.config = {
    alignment = 'bottom_right',
    background = true,
    double_buffer = true,
    font = 'DejaVu Sans:bold:size=14',
    gap_x = 20,
    gap_y = 20,
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
    draw_shads = true,
    default_shade_color = '000000',
    update_interval = 60,
    use_xft = true,
};
conky.text = [[
\${color white}$HOSTNAME_LABEL
]];
CONKYCONF
    chown "$user:$user" "$user_home/.config/conky_hostname.conf"
    # Recreate autostart
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
