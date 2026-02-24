#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
source ./watchdog_hosts.conf 2>/dev/null || { echo "ERROR: watchdog_hosts.conf not found!"; exit 1; }
echo "=== Install Connectivity Watchdog ==="
echo "72-hour self-destruct if configured hosts are unreachable."
echo ""
echo "Configured hosts:"
echo "  Host 1: ${HOST_1:-not set}"
echo "  Host 2: ${HOST_2:-not set}"
[ -n "$HOST_3" ] && echo "  Host 3: $HOST_3"
echo ""
echo "WARNING: This installs a REAL self-destruct mechanism!"
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
LOCAL_SCRIPT="/tmp/_install_watchdog.sh"
REMOTE_SCRIPT="/tmp/_install_watchdog.sh"
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
# Replace placeholders with actual host values
sed -i "s/__HOST_1__/$HOST_1/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_2__/$HOST_2/g" "$LOCAL_SCRIPT"
sed -i "s/__HOST_3__/$HOST_3/g" "$LOCAL_SCRIPT"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing watchdog..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null || true
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo "Done."
