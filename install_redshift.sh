#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Install Redshift ==="
echo "Installs Redshift for automatic screen color temperature."
echo ""
run_host() {
    local host="$1"
    echo "[$host] Installing Redshift..."
    remote_exec "$host" \
        'sudo -n bash -ec "
        DEBIAN_FRONTEND=noninteractive apt-get install -y redshift redshift-gtk
        for user_home in /home/*; do
            user=\$(basename \"\$user_home\")
            id \"\$user\" &>/dev/null || continue
            mkdir -p \"\$user_home/.config/autostart\"
            cat > \"\$user_home/.config/autostart/redshift-gtk.desktop\" << RSDESKTOP
[Desktop Entry]
Type=Application
Name=Redshift
Exec=redshift-gtk
Hidden=false
X-GNOME-Autostart-enabled=true
RSDESKTOP
            chown \"\$user:\$user\" \"\$user_home/.config/autostart/redshift-gtk.desktop\"
        done
        echo \"Redshift installed with autostart\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
}
fleet_run run_host
echo ""
echo "Done. Redshift starts automatically on next login."
