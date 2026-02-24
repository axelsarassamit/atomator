#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Set Wallpaper ==="
echo "Downloads a random wallpaper from wallpapers.txt and applies it."
echo ""
WALLPAPER_FILE="wallpapers.txt"
if [ ! -f "$WALLPAPER_FILE" ]; then echo "Error: $WALLPAPER_FILE not found!"; exit 1; fi
URLS=($(grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$"))
if [ ${#URLS[@]} -eq 0 ]; then echo "No URLs in $WALLPAPER_FILE"; exit 1; fi
RANDOM_URL="${URLS[$RANDOM % ${#URLS[@]}]}"
echo "Wallpaper: $RANDOM_URL"
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Setting wallpaper..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c '
        wget -q -O /tmp/wallpaper.jpg \"$RANDOM_URL\" 2>/dev/null || curl -sL -o /tmp/wallpaper.jpg \"$RANDOM_URL\" 2>/dev/null
        cp /tmp/wallpaper.jpg /usr/share/backgrounds/remote_wallpaper.jpg 2>/dev/null
        for user_home in /home/*; do
            user=\$(basename \"\$user_home\")
            id \"\$user\" &>/dev/null || continue
            for mon in monitor0 monitorDP-1 monitorHDMI-1 monitorVGA-1; do
                su - \"\$user\" -c \"DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/\$(id -u \$user)/bus xfconf-query -c xfce4-desktop -p /backdrop/screen0/\$mon/workspace0/last-image -s /usr/share/backgrounds/remote_wallpaper.jpg 2>/dev/null\" || true
            done
        done
        rm -f /tmp/wallpaper.jpg
        echo \"Wallpaper set\"
    '" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
