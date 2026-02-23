#!/bin/bash
set +e
echo "=== Install Hostname Display ==="
echo "Installs conky to show hostname in bottom-right corner of desktop."
echo ""
LOCAL_SCRIPT="/tmp/_install_hostname_display.sh"
REMOTE_SCRIPT="/tmp/_install_hostname_display.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
DEBIAN_FRONTEND=noninteractive apt-get install -y conky-all
HOSTNAME_LABEL=$(hostname)
for user_home in /home/*; do
    user=$(basename "$user_home")
    id "$user" &>/dev/null || continue
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
    sshpass -p 'sweetcom' scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" sweetagent@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        "echo sweetcom | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done. Shows after next login/reboot."
