#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
set +e
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
echo "=== Check Uptime ==="
echo "Shows how long each host has been running."
echo ""
HOST_COUNT=$(grep -v "^#" hosts.txt | grep -v "^$" | wc -l | tr -d ' ')
OUTPUT_FILE="uptime_$(date +%Y%m%d_%H%M%S).txt"
echo "Report: Uptime" > "$OUTPUT_FILE"
echo "Date: $(date '+%Y-%m-%d %H:%M:%S')" >> "$OUTPUT_FILE"
echo "Hosts: $HOST_COUNT" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"
printf "IP\tHostname\tUptime\tSince\n" >> "$OUTPUT_FILE"
ONLINE=0; OFFLINE=0
for host in "${ATOMATOR_HOSTS[@]}"; do
    RESULT=$(remote_exec "$host" \
        'echo "$(hostname)|$(uptime -p 2>/dev/null || echo N/A)|$(uptime -s 2>/dev/null || echo N/A)"' 2>/dev/null) || true
    if [ -n "$RESULT" ]; then
        HNAME=$(echo "$RESULT" | cut -d'|' -f1); UP=$(echo "$RESULT" | cut -d'|' -f2); SINCE=$(echo "$RESULT" | cut -d'|' -f3)
        echo -e "  \033[0;32m$host\033[0m ($HNAME) - $UP (since $SINCE)"
        printf "%s\t%s\t%s\t%s\n" "$host" "$HNAME" "$UP" "$SINCE" >> "$OUTPUT_FILE"
        ONLINE=$((ONLINE + 1))
    else
        echo -e "  \033[0;31m$host\033[0m - OFFLINE"
        printf "%s\t-\t-\tOFFLINE\n" "$host" >> "$OUTPUT_FILE"
        OFFLINE=$((OFFLINE + 1))
    fi
done
echo "" >> "$OUTPUT_FILE"
echo "Total: $HOST_COUNT hosts | Online: $ONLINE | Offline: $OFFLINE" >> "$OUTPUT_FILE"
echo ""
echo "Online: $ONLINE | Offline: $OFFLINE"
echo "Saved to: $OUTPUT_FILE"
