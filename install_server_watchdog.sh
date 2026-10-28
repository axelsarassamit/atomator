#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
if (($# == 0)); then
    servers_file=$(mktemp) || exit 1
    trap 'rm -f -- "$servers_file"' EXIT
    echo 'Additional servers, one hostname or IP per line. Empty line to finish:'
    while read -r -p 'Server: ' server && [[ -n "$server" ]]; do
        printf '%s\n' "$server" >> "$servers_file"
    done
    [[ -s "$servers_file" ]] || exit 0
    read -r -p 'SSH username [root]: ' SSH_USER || exit 0
    SSH_USER=${SSH_USER:-root}
    IFS= read -r -s -p 'SSH password (empty to use keys/agent): ' SSH_PASSWORD || exit 0
    echo
    runtime_init --hosts-file "$servers_file"
    rm -f -- "$servers_file"
else
    runtime_init "$@"
fi
runtime_watchdog_config || exit $?
echo "Installs the existing 72-hour destructive watchdog on the selected servers."
read -r -p "Install REAL self-destruct mechanism? (yes/no): " confirm
[[ "$confirm" == yes ]] || exit 0
LOCAL_SCRIPT="$ATOMATOR_RUN_DIR/payload.sh"
cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash
mkdir -p /var/lib/connectivity-watchdog
cat > /usr/local/bin/connectivity-watchdog.sh << 'WATCHDOG'
#!/bin/bash
PRIMARY_HOST="__HOST_1__"
SECONDARY_HOST="__HOST_2__"
TERTIARY_HOST="__HOST_3__"
TIMEOUT_SECONDS=259200
STATE_FILE="/var/lib/connectivity-watchdog/state"
TIMER_FILE="/var/lib/connectivity-watchdog/timer"
mkdir -p /var/lib/connectivity-watchdog
check_connectivity() {
    ping -c 1 -W 2 "$PRIMARY_HOST" &>/dev/null && return 0
    ping -c 1 -W 2 "$SECONDARY_HOST" &>/dev/null && return 0
    [ -n "$TERTIARY_HOST" ] && ping -c 1 -W 2 "$TERTIARY_HOST" &>/dev/null && return 0
    return 1
}
perform_wipe() {
    logger -t connectivity-watchdog "CRITICAL: 72h timeout. Wiping system."
    for disk in $(lsblk -dpno NAME | grep -E "sd|nvme|vd"); do
        dd if=/dev/zero of="$disk" bs=1M count=1024 2>/dev/null &
    done
    wait; sync; poweroff -f
}
if check_connectivity; then
    if [ -f "$STATE_FILE" ]; then
        logger -t connectivity-watchdog "Connection restored. Timer reset."
        rm -f "$STATE_FILE" "$TIMER_FILE"
    fi
else
    if [ ! -f "$STATE_FILE" ]; then
        date +%s > "$STATE_FILE"
        logger -t connectivity-watchdog "Connection lost. 72h countdown started."
    else
        LOST_TIME=$(cat "$STATE_FILE"); CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - LOST_TIME)); echo "$ELAPSED" > "$TIMER_FILE"
        if [ $ELAPSED -ge $TIMEOUT_SECONDS ]; then perform_wipe
        else HOURS=$(( (TIMEOUT_SECONDS - ELAPSED) / 3600 )); logger -t connectivity-watchdog "No connection. ${HOURS}h remaining."; fi
    fi
fi
WATCHDOG
chmod +x /usr/local/bin/connectivity-watchdog.sh
cat > /etc/systemd/system/connectivity-watchdog.service << 'SERVICE'
[Unit]
Description=Connectivity Watchdog (72h self-destruct)
After=network-online.target
Wants=network-online.target
[Service]
Type=oneshot
ExecStart=/usr/local/bin/connectivity-watchdog.sh
[Install]
WantedBy=multi-user.target
SERVICE
cat > /etc/systemd/system/connectivity-watchdog.timer << 'TIMER'
[Unit]
Description=Connectivity Watchdog Timer (every 5 min)
[Timer]
OnBootSec=60sec
OnUnitActiveSec=300sec
Persistent=true
[Install]
WantedBy=timers.target
TIMER
cat > /usr/local/bin/watchdog-status.sh << 'STATUS'
#!/bin/bash
STATE_FILE="/var/lib/connectivity-watchdog/state"
echo "=== Connectivity Watchdog Status ==="
if systemctl is-active connectivity-watchdog.timer &>/dev/null; then echo "Service: ACTIVE"; else echo "Service: INACTIVE"; fi
if [ ! -f "$STATE_FILE" ]; then echo "Status: OK - Connected"
else
    LOST_TIME=$(cat "$STATE_FILE"); ELAPSED=$(($(date +%s) - LOST_TIME))
    echo "Status: WARNING - No connection"
    echo "Elapsed: $((ELAPSED/3600))h $(((ELAPSED%3600)/60))m"
    echo "Wipe in: $(((259200-ELAPSED)/3600))h $(( ((259200-ELAPSED)%3600)/60 ))m"
fi
STATUS
chmod +x /usr/local/bin/watchdog-status.sh
systemctl daemon-reload
systemctl enable connectivity-watchdog.timer
systemctl start connectivity-watchdog.timer
systemctl start connectivity-watchdog.service
echo "Watchdog installed (72h timeout, checks every 5min)"
SCRIPT

# Replace placeholders with actual ping host values
sed -i "s/__HOST_1__/$HOST_1/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_2__/$HOST_2/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_3__/$HOST_3/g" "$LOCAL_SCRIPT"

install_host() { remote_script "$1" "$LOCAL_SCRIPT"; }
fleet_run install_host
