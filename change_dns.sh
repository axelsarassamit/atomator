#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Change DNS Servers ==="
echo ""
echo "DNS servers to set:"
echo "  1. Cloudflare + Google + Quad9 (1.1.1.1 8.8.8.8 9.9.9.9)"
echo "  2. Enter custom DNS servers"
echo ""
read -p "Choice [1-2] (default 1): " dns_choice
case $dns_choice in
    2)
        echo ""
        read -p "Enter DNS servers (space-separated, e.g. 10.0.0.5 1.1.1.1): " CUSTOM_DNS
        if [ -z "$CUSTOM_DNS" ]; then echo "No DNS entered. Cancelled."; exit 1; fi
        DNS_SERVERS="$CUSTOM_DNS"
        ;;
    *)
        DNS_SERVERS="1.1.1.1 8.8.8.8 9.9.9.9"
        ;;
esac
echo ""
echo "Setting DNS to: $DNS_SERVERS"
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-5}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

run_host() {
    local host="$1" idx="$2"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        CON_NAME=\$(nmcli -t -f NAME,TYPE connection show --active | grep ethernet | head -1 | cut -d: -f1)
        if [ -n \"\$CON_NAME\" ]; then
            nmcli con mod \"\$CON_NAME\" ipv4.dns \"'"$DNS_SERVERS"'\"
            nmcli con mod \"\$CON_NAME\" ipv4.ignore-auto-dns yes
            nmcli con up \"\$CON_NAME\" 2>/dev/null || true
        else
            exit 1
        fi
    "' &>/dev/null
    [ $? -eq 0 ] && echo "OK" > "$TMPDIR/$idx" || echo "FAIL" > "$TMPDIR/$idx"
}

for i in "${!HOSTS[@]}"; do
    run_host "${HOSTS[$i]}" "$i" &
    echo "[$((i+1))/$TOTAL] ${HOSTS[$i]} - started"
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.5; done
done
wait

OK_COUNT=0; FAIL_COUNT=0
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
