#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect Hardware Info ==="
echo "Gathers hostname, manufacturer, model, CPU, RAM, disk from all hosts."
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="hardware_info_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Hardware Info" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tManufacturer\tModel\tSerial\tCPU\tCores\tRAM\tDisk_Total\tDisk_Free\tOS\tKernel\tUptime\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo -n "[$host] Collecting... "
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        HNAME=\$(hostname)
        MFR=\$(dmidecode -s system-manufacturer 2>/dev/null || echo N/A)
        MDL=\$(dmidecode -s system-product-name 2>/dev/null || echo N/A)
        SER=\$(dmidecode -s system-serial-number 2>/dev/null || echo N/A)
        CPU=\$(grep -m1 \"model name\" /proc/cpuinfo 2>/dev/null | cut -d: -f2 | xargs || echo N/A)
        COR=\$(nproc 2>/dev/null || echo N/A)
        RAM=\$(free -h | awk \"/Mem:/{print \\\$2}\")
        DTOT=\$(df -h / | awk \"NR==2{print \\\$2}\")
        DFREE=\$(df -h / | awk \"NR==2{print \\\$4}\")
        OS=\$(lsb_release -ds 2>/dev/null || grep PRETTY_NAME /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d \\\"\\\")
        KER=\$(uname -r)
        UPT=\$(uptime -p 2>/dev/null || echo N/A)
        echo \"\$HNAME|\$MFR|\$MDL|\$SER|\$CPU|\$COR|\$RAM|\$DTOT|\$DFREE|\$OS|\$KER|\$UPT\"
    "' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1)
        MFR=$(echo "$RESULT" | cut -d'|' -f2)
        MDL=$(echo "$RESULT" | cut -d'|' -f3)
        SER=$(echo "$RESULT" | cut -d'|' -f4)
        CPU=$(echo "$RESULT" | cut -d'|' -f5)
        COR=$(echo "$RESULT" | cut -d'|' -f6)
        RAM=$(echo "$RESULT" | cut -d'|' -f7)
        DTOT=$(echo "$RESULT" | cut -d'|' -f8)
        DFREE=$(echo "$RESULT" | cut -d'|' -f9)
        OS=$(echo "$RESULT" | cut -d'|' -f10)
        KER=$(echo "$RESULT" | cut -d'|' -f11)
        UPT=$(echo "$RESULT" | cut -d'|' -f12-)
        echo -e "\033[0;32mOK\033[0m - $HNAME | $MFR $MDL | $RAM RAM"
        printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$MFR" "$MDL" "$SER" "$CPU" "$COR" "$RAM" "$DTOT" "$DFREE" "$OS" "$KER" "$UPT" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "\033[0;31mFAILED\033[0m"
        printf "%s\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
