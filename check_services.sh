#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Check Services ==="
echo "Shows status of important services on all hosts."
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="services_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Services" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tSSH\tNetworkManager\tCron\tRsyslog\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'HNAME=$(hostname); S1=$(systemctl is-active ssh 2>/dev/null || echo inactive); S2=$(systemctl is-active NetworkManager 2>/dev/null || echo inactive); S3=$(systemctl is-active cron 2>/dev/null || echo inactive); S4=$(systemctl is-active rsyslog 2>/dev/null || echo inactive); echo "$HNAME|$S1|$S2|$S3|$S4"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        S1=$(echo "$RESULT" | cut -d'|' -f2); [ "$S1" = "active" ] && S1="OK" || S1="FAIL"
        S2=$(echo "$RESULT" | cut -d'|' -f3); [ "$S2" = "active" ] && S2="OK" || S2="FAIL"
        S3=$(echo "$RESULT" | cut -d'|' -f4); [ "$S3" = "active" ] && S3="OK" || S3="FAIL"
        S4=$(echo "$RESULT" | cut -d'|' -f5); [ "$S4" = "active" ] && S4="OK" || S4="FAIL"
        echo -n "  $host ($HNAME) - "
        for s in "SSH:$S1" "NM:$S2" "Cron:$S3" "Rsyslog:$S4"; do
            SN=${s%%:*}; SV=${s##*:}
            if [ "$SV" = "OK" ]; then echo -ne "\033[0;32m$SN:OK\033[0m "; else echo -ne "\033[0;31m$SN:FAIL\033[0m "; fi
        done
        echo ""
        printf "%s\t%s\t%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$S1" "$S2" "$S3" "$S4" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m$host\033[0m - OFFLINE"
        printf "%s\t-\t-\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
