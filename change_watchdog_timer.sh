#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'

echo -e "${CYAN}=== Change Watchdog Self-Destruct Timer ===${NC}"
echo ""
echo "Updates TIMEOUT_SECONDS in /usr/local/bin/connectivity-watchdog.sh on"
echo "every host in hosts.txt. Default in fresh installs is 72 hours."
echo ""
echo "Any in-progress countdown is cleared, so a shorter new timeout will"
echo "not immediately wipe a host that was already mid-countdown."
echo ""

read -p "  New timeout in HOURS [1-720, default 72]: " hours
[ -z "$hours" ] && hours=72

if ! [[ "$hours" =~ ^[0-9]+$ ]] || [ "$hours" -lt 1 ] || [ "$hours" -gt 720 ]; then
    echo -e "${RED}Invalid input. Must be an integer between 1 and 720.${NC}"
    exit 1
fi

NEW_SECONDS=$((hours * 3600))

echo ""
echo -e "  New timeout: ${YELLOW}${hours}h${NC} (${NEW_SECONDS}s)"
echo ""
read -p "  Apply to all hosts in hosts.txt? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""

LOCAL_SCRIPT="/tmp/_change_watchdog_timer.sh"
REMOTE_SCRIPT="/tmp/_change_watchdog_timer.sh"
cat > "$LOCAL_SCRIPT" << SCRIPT
#!/bin/bash
if [ ! -f /usr/local/bin/connectivity-watchdog.sh ]; then
    echo MISSING
    exit 0
fi
sed -i 's/^TIMEOUT_SECONDS=.*/TIMEOUT_SECONDS=$NEW_SECONDS/' /usr/local/bin/connectivity-watchdog.sh
rm -f /var/lib/connectivity-watchdog/state /var/lib/connectivity-watchdog/timer
echo OK
SCRIPT

OK_COUNT=0; FAIL_COUNT=0; MISSING_COUNT=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Updating watchdog timer..."
    sshpass -p "$SSH_PASS" scp -o StrictHostKeyChecking=no "$LOCAL_SCRIPT" "$SSH_USER"@"$host":"$REMOTE_SCRIPT" 2>/dev/null
    if [ $? -ne 0 ]; then
        echo -e "[$host] ${RED}FAILED${NC} (scp)"
        FAIL_COUNT=$((FAIL_COUNT + 1))
        continue
    fi
    OUT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash $REMOTE_SCRIPT && rm -f $REMOTE_SCRIPT" 2>/dev/null)
    if echo "$OUT" | grep -q "MISSING"; then
        echo -e "[$host] ${YELLOW}NOT INSTALLED${NC} (skipped)"
        MISSING_COUNT=$((MISSING_COUNT + 1))
    elif echo "$OUT" | grep -q "OK"; then
        echo -e "[$host] ${GREEN}OK${NC}"
        OK_COUNT=$((OK_COUNT + 1))
    else
        echo -e "[$host] ${RED}FAILED${NC}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done
rm -f "$LOCAL_SCRIPT"
echo ""
echo -e "Updated: ${GREEN}${OK_COUNT}${NC}  Failed: ${RED}${FAIL_COUNT}${NC}  Not installed: ${YELLOW}${MISSING_COUNT}${NC}"
echo "Done."
