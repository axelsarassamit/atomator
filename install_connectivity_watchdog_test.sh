#!/bin/bash
set +e

echo "=== Installing Connectivity Watchdog (TEST MODE - No Wipe) ==="
echo ""
echo "This TEST version will:"
echo "  - Monitor connectivity to 192.168.1.242 and ntp.sweetserver.wan"
echo "  - Start a 72-hour countdown if both are unreachable"
echo "  - LOG what would happen but NOT actually wipe the system"
echo "  - Use a 5-minute timeout for faster testing (instead of 72 hours)"
echo ""

# Write the remote script to a local temp file
LOCAL_SCRIPT='/tmp/_install_watchdog_test.sh'
REMOTE_SCRIPT='/tmp/_install_watchdog_test.sh'

cat > "$LOCAL_SCRIPT" << 'SCRIPT'
#!/bin/bash

echo "Installing Connectivity Watchdog (TEST MODE)..."

# Create the watchdog script
cat > /usr/local/bin/connectivity-watchdog-test.sh << 'WATCHDOG'
#!/bin/bash

# Connectivity check targets
PRIMARY_HOST="192.168.1.242"
SECONDARY_HOST="ntp.sweetserver.wan"

# TEST MODE: 5 minutes instead of 72 hours for faster testing
TIMEOUT_SECONDS=300

# State file to track when connectivity was lost
STATE_FILE="/var/lib/connectivity-watchdog-test/state"
TIMER_FILE="/var/lib/connectivity-watchdog-test/timer"

# Create state directory
mkdir -p /var/lib/connectivity-watchdog-test

# Function to check connectivity
check_connectivity() {
    # Try primary host
    if ping -c 1 -W 2 "$PRIMARY_HOST" &>/dev/null; then
        return 0
    fi

    # Try secondary host
    if ping -c 1 -W 2 "$SECONDARY_HOST" &>/dev/null; then
        return 0
    fi

    # Both failed
    return 1
}

# Function to simulate wipe (TEST MODE - does NOT actually wipe)
simulate_wipe() {
    logger -t connectivity-watchdog-test "TEST MODE: 5-minute timeout reached. Would initiate system wipe now."
    echo "========================================" >> /var/log/connectivity-watchdog-test.log
    echo "$(date): TEST MODE - WIPE WOULD OCCUR NOW" >> /var/log/connectivity-watchdog-test.log
    echo "In production, this would:" >> /var/log/connectivity-watchdog-test.log
    echo "  1. Overwrite all disks with zeros (dd if=/dev/zero)" >> /var/log/connectivity-watchdog-test.log
    echo "  2. Force poweroff" >> /var/log/connectivity-watchdog-test.log
    echo "========================================" >> /var/log/connectivity-watchdog-test.log

    # Keep the timer active to continue logging
    echo "WOULD_WIPE" > "$STATE_FILE.wiped"
}

# Check connectivity
if check_connectivity; then
    # Connection OK - reset timer
    if [ -f "$STATE_FILE" ]; then
        logger -t connectivity-watchdog-test "TEST: Connection restored. Resetting timer."
        rm -f "$STATE_FILE" "$TIMER_FILE" "$STATE_FILE.wiped"
        echo "$(date): Connection restored - Timer reset" >> /var/log/connectivity-watchdog-test.log
    fi
else
    # No connectivity
    if [ ! -f "$STATE_FILE" ]; then
        # First time losing connection - start timer
        LOST_TIME=$(date +%s)
        echo "$LOST_TIME" > "$STATE_FILE"
        logger -t connectivity-watchdog-test "TEST: Connection lost. Starting 5-minute countdown (would be 72h in production)."
        echo "$(date): Connection lost - Timer started" >> /var/log/connectivity-watchdog-test.log
    else
        # Connection already lost - check elapsed time
        LOST_TIME=$(cat "$STATE_FILE")
        CURRENT_TIME=$(date +%s)
        ELAPSED=$((CURRENT_TIME - LOST_TIME))
        REMAINING=$((TIMEOUT_SECONDS - ELAPSED))

        # Update timer file for status checks
        echo "$ELAPSED" > "$TIMER_FILE"

        if [ $ELAPSED -ge $TIMEOUT_SECONDS ] && [ ! -f "$STATE_FILE.wiped" ]; then
            # Timeout elapsed - simulate wipe
            simulate_wipe
        else
            # Still within timeout or already "wiped"
            MINUTES_REMAINING=$((REMAINING / 60))
            SECONDS_REMAINING=$((REMAINING % 60))

            if [ -f "$STATE_FILE.wiped" ]; then
                logger -t connectivity-watchdog-test "TEST: System would be wiped. Still no connection."
                echo "$(date): Still no connection - System would be wiped in production" >> /var/log/connectivity-watchdog-test.log
            else
                logger -t connectivity-watchdog-test "TEST: No connection. Time remaining: ${MINUTES_REMAINING}m ${SECONDS_REMAINING}s"
                echo "$(date): No connection - Time remaining: ${MINUTES_REMAINING}m ${SECONDS_REMAINING}s" >> /var/log/connectivity-watchdog-test.log
            fi
        fi
    fi
fi
WATCHDOG

chmod +x /usr/local/bin/connectivity-watchdog-test.sh

# Create systemd service
cat > /etc/systemd/system/connectivity-watchdog-test.service << 'SERVICE'
[Unit]
Description=Connectivity Watchdog TEST MODE (5min timeout)
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/connectivity-watchdog-test.sh
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SERVICE

# Create systemd timer (runs every 30 seconds for testing)
cat > /etc/systemd/system/connectivity-watchdog-test.timer << 'TIMER'
[Unit]
Description=Connectivity Watchdog TEST Timer (Check every 30 seconds)

[Timer]
OnBootSec=10sec
OnUnitActiveSec=30sec
Persistent=true

[Install]
WantedBy=timers.target
TIMER

# Reload systemd
systemctl daemon-reload

# Enable and start the timer
systemctl enable connectivity-watchdog-test.timer
systemctl start connectivity-watchdog-test.timer

# Run once immediately
systemctl start connectivity-watchdog-test.service

# Create status check script
cat > /usr/local/bin/watchdog-test-status.sh << 'STATUS'
#!/bin/bash

STATE_FILE="/var/lib/connectivity-watchdog-test/state"
TIMER_FILE="/var/lib/connectivity-watchdog-test/timer"
LOG_FILE="/var/log/connectivity-watchdog-test.log"

echo "=== Connectivity Watchdog TEST MODE Status ==="
echo ""

if [ ! -f "$STATE_FILE" ]; then
    echo "✓ Connectivity OK - Timer not active"
else
    LOST_TIME=$(cat "$STATE_FILE")
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - LOST_TIME))
    MINUTES_ELAPSED=$((ELAPSED / 60))
    SECONDS_ELAPSED=$((ELAPSED % 60))

    TIMEOUT_SECONDS=300
    REMAINING=$((TIMEOUT_SECONDS - ELAPSED))
    MINUTES_REMAINING=$((REMAINING / 60))
    SECONDS_REMAINING=$((REMAINING % 60))

    echo "⚠ WARNING: No connectivity detected (TEST MODE)"
    echo "Connection lost at: $(date -d @$LOST_TIME)"
    echo "Time elapsed: ${MINUTES_ELAPSED}m ${SECONDS_ELAPSED}s"

    if [ -f "$STATE_FILE.wiped" ]; then
        echo "Status: ❌ TIMEOUT REACHED - Would wipe in production mode"
    else
        echo "Time remaining: ${MINUTES_REMAINING}m ${SECONDS_REMAINING}s"
    fi

    echo ""
    echo "NOTE: This is TEST MODE with 5-minute timeout"
    echo "Production mode would use 72 hours (259200 seconds)"
fi

echo ""
echo "=== Recent Log Entries ==="
if [ -f "$LOG_FILE" ]; then
    tail -n 10 "$LOG_FILE"
else
    echo "No log file yet"
fi
STATUS

chmod +x /usr/local/bin/watchdog-test-status.sh

# Create log file
touch /var/log/connectivity-watchdog-test.log
chmod 644 /var/log/connectivity-watchdog-test.log

echo ""
echo "✓ Connectivity Watchdog TEST MODE installed and active"
echo ""
echo "TEST SETTINGS:"
echo "  - Timeout: 5 minutes (instead of 72 hours)"
echo "  - Check interval: 30 seconds (instead of 5 minutes)"
echo "  - Monitoring: 192.168.1.242 and ntp.sweetserver.wan"
echo "  - Action on timeout: LOG ONLY (no actual wipe)"
echo ""
echo "Check status: sudo /usr/local/bin/watchdog-test-status.sh"
echo "View logs: tail -f /var/log/connectivity-watchdog-test.log"
echo ""
echo "To test: Disconnect network and watch the countdown"
SCRIPT

for host in $(grep -v "^#" hosts.txt | grep -v "^$")
do
    echo "Processing $host..."

    # Upload script to remote host
    sshpass -p 'sweetcom' scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" sweetagent@"$host":"$REMOTE_SCRIPT" || true

    # Execute with sudo and cleanup
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" "echo sweetcom | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" || true

    if [ $? -eq 0 ]; then
        echo "$host: SUCCESS"
    else
        echo "$host: FAILED"
    fi
done

# Cleanup local temp file
rm -f "$LOCAL_SCRIPT"

echo ""
echo "All hosts processed."
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📊 MONITORING TEST MODE:"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Check status on any host:"
echo "  ssh sweetagent@HOST 'echo sweetcom | sudo -S /usr/local/bin/watchdog-test-status.sh'"
echo ""
echo "Watch live logs on any host:"
echo "  ssh sweetagent@HOST 'tail -f /var/log/connectivity-watchdog-test.log'"
echo ""
echo "To test the countdown:"
echo "  1. Disconnect the network cable or disable network"
echo "  2. Wait 5 minutes"
echo "  3. Check logs to see it would have wiped"
echo "  4. Reconnect network - timer should reset"
echo ""
