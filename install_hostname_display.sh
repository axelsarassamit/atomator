#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Install Hostname Display ==="
echo "Installs conky to show hostname in bottom-right corner of desktop."
echo ""
LOCAL_SCRIPT="$ATOMATOR_RUN_DIR/payload.sh"
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
    # Enable Xfce compositor (required for true transparency)
    if who | grep -q "^$user "; then
        su - "$user" -c "DISPLAY=:0 xfconf-query -c xfwm4 -p /general/use_compositing -s true" 2>/dev/null || true
    fi
    # Also set it in xfce config file for next login
    mkdir -p "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml"
    if [ -f "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" ]; then
        sed -i 's|name="use_compositing" type="bool" value="false"|name="use_compositing" type="bool" value="true"|g' \
            "$user_home/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml" 2>/dev/null || true
    fi
    # Create config with ARGB transparency (works with compositor)
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
    own_window_transparent = false,
    own_window_hints = 'undecorated,below,sticky,skip_taskbar,skip_pager',
    own_window_argb_visual = true,
    own_window_argb_value = 0,
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
run_host() {
    local host="$1"
    echo "[$host] Installing..."
        remote_script "$host" "$LOCAL_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done. Shows after next login/reboot."
