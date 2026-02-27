#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Hostname Display ==="
echo "Installs conky to show hostname in bottom-right corner of desktop."
echo ""
LOCAL_SCRIPT="/tmp/_install_hostname_display.sh"
REMOTE_SCRIPT="/tmp/_install_hostname_display.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get install -y conky-all
# Kill any existing conky
pkill -f "conky" 2>/dev/null || true
sleep 1
HOSTNAME_LABEL=$(hostname)
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
    gap_y = 26,
    own_window = true,
    own_window_type = 'desktop',
    own_window_transparent = true,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    draw_shads = true,
    default_shade_color = '000000',
    draw_outline = true,
    default_outline_color = '000000',
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
done
echo "Hostname display installed"
SCRIPT
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done. Shows after next login/reboot."
