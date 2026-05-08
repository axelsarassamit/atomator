#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== System Cleanup ==="
echo "Cleans APT cache, old logs, temp files and trash on all hosts."
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
        apt-get clean -y
        apt-get autoclean -y
        apt-get autoremove -y
        journalctl --vacuum-time=7d 2>/dev/null || true
        find /tmp -type f -atime +7 -delete 2>/dev/null || true
        find /var/tmp -type f -atime +7 -delete 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/files/* 2>/dev/null || true
        rm -rf /home/*/.local/share/Trash/info/* 2>/dev/null || true
        rm -rf /home/*/.cache/thumbnails/* 2>/dev/null || true
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
