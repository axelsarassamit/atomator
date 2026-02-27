#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Install Redshift ==="
echo "Installs Redshift for automatic screen color temperature."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Redshift..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        DEBIAN_FRONTEND=noninteractive apt-get install -y redshift redshift-gtk 2>/dev/null || true
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
done
echo ""
echo "Done. Redshift starts automatically on next login."
