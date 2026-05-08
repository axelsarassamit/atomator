#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Update & Remove Old Kernels ==="
echo "Updates all systems and purges old kernel packages to free disk space."
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
        'echo '"$SSH_PASS"' | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge && apt-get autoclean -y"' &>/dev/null
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
