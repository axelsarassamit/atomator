#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
mapfile -t URLS < <(sed '/^[[:space:]]*#/d; /^[[:space:]]*$/d' wallpapers.txt)
((${#URLS[@]})) || { echo 'No URLs in wallpapers.txt' >&2; exit 64; }
URL=${URLS[$RANDOM % ${#URLS[@]}]}
[[ "$URL" == https://* ]] || { echo 'Wallpaper URL must use HTTPS.' >&2; exit 64; }
cat > "$ATOMATOR_RUN_DIR/payload.sh" <<'PAYLOAD'
tmp=$(mktemp)
trap 'rm -f -- "$tmp"' EXIT
curl --fail --silent --show-error --location --output "$tmp" -- "$1"
install -m 644 "$tmp" /usr/share/backgrounds/remote_wallpaper.jpg
for user_home in /home/*; do
    user=$(basename "$user_home")
    id "$user" >/dev/null 2>&1 || continue
    for mon in monitor0 monitorDP-1 monitorHDMI-1 monitorVGA-1; do
        runuser -u "$user" -- env DISPLAY=:0 DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u "$user")/bus" \
            xfconf-query -c xfce4-desktop -p "/backdrop/screen0/$mon/workspace0/last-image" -s /usr/share/backgrounds/remote_wallpaper.jpg 2>/dev/null || true
    done
done
PAYLOAD
run_host() { remote_script "$1" "$ATOMATOR_RUN_DIR/payload.sh" "$URL"; }
fleet_run run_host
