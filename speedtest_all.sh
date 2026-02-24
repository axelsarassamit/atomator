#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Speed Test All Hosts ==="
echo ""
OUTPUT_FILE="speedtest_results_$(date +%Y%m%d_%H%M%S).txt"
echo "Speed Test - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Testing (takes a moment)..."
    RESULT=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "which speedtest-cli >/dev/null 2>&1 || apt-get install -y speedtest-cli >/dev/null 2>&1; speedtest-cli --simple 2>/dev/null || echo \"Failed\""' 2>/dev/null) || true
    echo "  $RESULT"
    echo -e "\n$host:\n$RESULT" >> "$OUTPUT_FILE"
done
echo ""
echo "Saved to: $OUTPUT_FILE"
