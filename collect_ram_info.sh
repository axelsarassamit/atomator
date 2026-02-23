#!/bin/bash
set +e
echo "=== Collect RAM Info ==="
echo ""
OUTPUT_FILE="ram_info_$(date +%Y%m%d_%H%M%S).txt"
echo "RAM Report - $(date)" > "$OUTPUT_FILE"
TOTAL_RAM=0; HOST_COUNT=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Collecting RAM..."
    INFO=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        echo \"  Hostname: \$(hostname)\"
        free -h | awk \"/Mem:/{print \\\"  Total: \\\" \\\$2 \\\"  Used: \\\" \\\$3 \\\"  Free: \\\" \\\$4}\"
    "' 2>/dev/null) || true
    RAM_MB=$(sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" 'free -m | awk "/Mem:/{print \$2}"' 2>/dev/null) || true
    if [ -n "$RAM_MB" ] && [ "$RAM_MB" -gt 0 ] 2>/dev/null; then
        TOTAL_RAM=$((TOTAL_RAM + RAM_MB)); HOST_COUNT=$((HOST_COUNT + 1))
    fi
    echo "$INFO"
    echo -e "\n$host:\n$INFO" >> "$OUTPUT_FILE"
done
if [ $HOST_COUNT -gt 0 ]; then
    echo ""
    echo "Summary: $HOST_COUNT hosts | Total: $((TOTAL_RAM / 1024)) GB | Avg: $((TOTAL_RAM / HOST_COUNT / 1024)) GB/host"
fi
echo ""
echo "Saved to: $OUTPUT_FILE"
