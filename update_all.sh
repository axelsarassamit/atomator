#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Update All Systems ==="
echo "Runs apt update, upgrade, autoremove and autoclean on all hosts."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-5}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OK_COUNT=0; FAIL_COUNT=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

run_update() {
    local host="$1" idx="$2"
    local out
    out=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y && apt-get autoclean -y"' 2>&1)
    if [ $? -eq 0 ]; then
        echo "OK" > "$TMPDIR/$idx"
    else
        echo "FAIL" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    run_update "${HOSTS[$i]}" "$i" &
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
