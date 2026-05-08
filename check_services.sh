#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Services ==="
echo "Shows status of important services on all hosts."
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-10}
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
OUTPUT_FILE="services_$(date +%Y%m%d_%H%M%S).txt"
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

echo "Report: Services" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $TOTAL" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tSSH\tNetworkManager\tCron\tRsyslog\n" >> "$OUTPUT_FILE"

check_host() {
    local host="$1" idx="$2"
    local result
    result=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'HNAME=$(hostname); S1=$(systemctl is-active ssh 2>/dev/null || echo inactive); S2=$(systemctl is-active NetworkManager 2>/dev/null || echo inactive); S3=$(systemctl is-active cron 2>/dev/null || echo inactive); S4=$(systemctl is-active rsyslog 2>/dev/null || echo inactive); echo "$HNAME|$S1|$S2|$S3|$S4"' 2>/dev/null)
    if [ -n "$result" ]; then
        echo "OK|$result" > "$TMPDIR/$idx"
    else
        echo "FAIL" > "$TMPDIR/$idx"
    fi
}

for i in "${!HOSTS[@]}"; do
    check_host "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.2; done
done
wait

ONLINE=0; OFFLINE=0
for i in "${!HOSTS[@]}"; do
    if [ -f "$TMPDIR/$i" ] && grep -q "OK" "$TMPDIR/$i"; then
        RESULT=$(cut -d'|' -f2- "$TMPDIR/$i")
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        S1=$(echo "$RESULT" | cut -d'|' -f2); [ "$S1" = "active" ] && S1="OK" || S1="FAIL"
        S2=$(echo "$RESULT" | cut -d'|' -f3); [ "$S2" = "active" ] && S2="OK" || S2="FAIL"
        S3=$(echo "$RESULT" | cut -d'|' -f4); [ "$S3" = "active" ] && S3="OK" || S3="FAIL"
        S4=$(echo "$RESULT" | cut -d'|' -f5); [ "$S4" = "active" ] && S4="OK" || S4="FAIL"
        echo -n "  ${HOSTS[$i]} ($HNAME) - "
        for s in "SSH:$S1" "NM:$S2" "Cron:$S3" "Rsyslog:$S4"; do
            SN=${s%%:*}; SV=${s##*:}
            if [ "$SV" = "OK" ]; then echo -ne "\033[0;32m$SN:OK\033[0m "; else echo -ne "\033[0;31m$SN:FAIL\033[0m "; fi
        done
        echo ""
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" "${HOSTS[$i]}" "$HNAME" "$S1" "$S2" "$S3" "$S4" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m${HOSTS[$i]}\033[0m - OFFLINE"
        printf "%s\t-\t-\t-\t-\tOFFLINE\n" "${HOSTS[$i]}" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done

echo "" >> "$OUTPUT_FILE"
echo "Total: $TOTAL hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE | ${ELAPSED}s"
echo "Saved to: $OUTPUT_FILE"
