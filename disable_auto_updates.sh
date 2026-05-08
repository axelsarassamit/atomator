#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Disable Automatic Updates ==="
echo "Stops and disables unattended-upgrades and apt timers on all hosts."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-5}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OK_COUNT=0; FAIL_COUNT=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

run_host() {
    local host="$1" idx="$2"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        systemctl stop unattended-upgrades 2>/dev/null || true
        systemctl disable unattended-upgrades 2>/dev/null || true
        systemctl stop apt-daily.timer 2>/dev/null || true
        systemctl disable apt-daily.timer 2>/dev/null || true
        systemctl stop apt-daily-upgrade.timer 2>/dev/null || true
        systemctl disable apt-daily-upgrade.timer 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get remove -y unattended-upgrades 2>/dev/null || true
        printf \"APT::Periodic::Update-Package-Lists \\\"0\\\";\\nAPT::Periodic::Unattended-Upgrade \\\"0\\\";\\nAPT::Periodic::Download-Upgradeable-Packages \\\"0\\\";\\nAPT::Periodic::AutocleanInterval \\\"0\\\";\\n\" > /etc/apt/apt.conf.d/20auto-upgrades
    "' &>/dev/null
    [ $? -eq 0 ] && echo "OK" > "$TMPDIR/$idx" || echo "FAIL" > "$TMPDIR/$idx"
}

for i in "${!HOSTS[@]}"; do
    run_host "${HOSTS[$i]}" "$i" &
    echo "[$((i+1))/$TOTAL] ${HOSTS[$i]} - started"
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.5; done
done
wait

for i in "${!HOSTS[@]}"; do
    if [ -f "$TMPDIR/$i" ] && grep -q "OK" "$TMPDIR/$i"; then
        echo -e "  \033[0;32m[OK]\033[0m     ${HOSTS[$i]}"
        OK_COUNT=$((OK_COUNT + 1))
    else
        echo -e "  \033[0;31m[FAILED]\033[0m ${HOSTS[$i]}"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
done

ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Done in ${ELAPSED}s | OK: $OK_COUNT | Failed: $FAIL_COUNT | Total: $TOTAL"
