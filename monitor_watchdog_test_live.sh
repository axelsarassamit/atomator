#!/bin/bash
set +e

# Check if host was provided
if [ -z "$1" ]; then
    echo "Usage: ./monitor_watchdog_test_live.sh <host_ip>"
    echo "Example: ./monitor_watchdog_test_live.sh 192.168.3.50"
    echo ""
    echo "This will show a live updating view of the watchdog test status."
    exit 1
fi

HOST="$1"

echo "=== Live Monitoring Watchdog TEST on $HOST ==="
echo "Press Ctrl+C to exit"
echo ""

# Continuous monitoring loop
while true; do
    clear
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📡 Live Watchdog Test Monitor - $HOST"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Updated: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Get status
    STATUS=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 sweetagent@"$HOST" "echo sweetcom | sudo -S /usr/local/bin/watchdog-test-status.sh 2>/dev/null" 2>/dev/null)

    if [ -n "$STATUS" ]; then
        echo "$STATUS"
    else
        echo "❌ Unable to connect to $HOST"
        echo "   - Host may be offline"
        echo "   - Watchdog test may not be installed"
    fi

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "Refreshing in 3 seconds... (Ctrl+C to exit)"

    # Wait 3 seconds before next update
    sleep 3
done
