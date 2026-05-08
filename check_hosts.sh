#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Host Status ==="
echo "Pings every host and shows hostname."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
ONLINE=0; OFFLINE=0
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

check_host() {
    local host="$1" idx="$2"
    if ping -c 1 -W 2 "$host" &>/dev/null; then
        HNAME=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 "$SSH_USER"@"$host" 'hostname' 2>/dev/null)
        [ -z "$HNAME" ] && HNAME="?"
        echo "ONLINE|$HNAME" > "$TMPDIR/$idx"
    else
        echo "OFFLINE" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    check_host "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.2; done
done
wait

for i in "${!HOSTS[@]}"; do
    if [ -f "$TMPDIR/$i" ] && grep -q "ONLINE" "$TMPDIR/$i"; then
        HNAME=$(cut -d'|' -f2 "$TMPDIR/$i")
        echo -e "  \033[0;32m[ONLINE]\033[0m  ${HOSTS[$i]}  ($HNAME)"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m[OFFLINE]\033[0m ${HOSTS[$i]}"
        OFFLINE=$((OFFLINE + 1))
    fi
done

ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Total: $TOTAL | Online: $ONLINE | Offline: $OFFLINE | ${ELAPSED}s"
