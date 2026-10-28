#!/bin/bash
# Deployment templates are inert until configure_site.py creates a configured bundle.
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != "1" ]]; then
    printf '%s\n' 'No site configured. Use configure_site.py with explicit site settings before running this script.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
HOSTS_FILE="hosts.txt"
fill_range() {
    echo -ne "${YELLOW}Enter IP range (e.g. 192.0.2.3-199): ${NC}"
    read RANGE
    python3 "$ATOMATOR_ROOT/lib/settings.py" range "$RANGE" >/dev/null || return 64
    BASE=$(echo "$RANGE" | grep -oE '^[0-9]+\.[0-9]+\.[0-9]+\.')
    START=$(echo "$RANGE" | grep -oE '\.[0-9]+-' | tr -d '.-')
    END=$(echo "$RANGE" | grep -oE -- '-[0-9]+$' | tr -d '-')
    if [ -z "$BASE" ] || [ -z "$START" ] || [ -z "$END" ]; then echo -e "${RED}Invalid format.${NC}"; return; fi
    cp "$HOSTS_FILE" "${HOSTS_FILE}.bak" 2>/dev/null
    echo "# Auto-generated on $(date)" > "$HOSTS_FILE"
    echo "# Range: ${BASE}${START} to ${BASE}${END}" >> "$HOSTS_FILE"
    COUNT=0
    for i in $(seq "$START" "$END"); do echo "${BASE}${i}" >> "$HOSTS_FILE"; COUNT=$((COUNT + 1)); done
    echo "# Total: $COUNT hosts" >> "$HOSTS_FILE"
    echo -e "${GREEN}Added $COUNT hosts${NC}"
}
while true; do
    echo ""
    echo -e "${CYAN}=== Manage hosts.txt ===${NC}"
    echo -e "${YELLOW}1.${NC} Fill with IP range"
    echo -e "${YELLOW}2.${NC} View hosts"
    echo -e "${YELLOW}3.${NC} Add a host"
    echo -e "${YELLOW}4.${NC} Remove a host"
    echo -e "${YELLOW}5.${NC} Remove duplicates"
    echo -e "${YELLOW}6.${NC} Sort hosts"
    echo -e "${YELLOW}7.${NC} Count hosts"
    echo -e "${YELLOW}8.${NC} Restore backup"
    echo -e "${YELLOW}0.${NC} Back"
    echo ""
    read -p "Choice [0-8]: " choice
    echo ""
    case $choice in
        1) fill_range ;;
        2) grep -v "^#" "$HOSTS_FILE" | grep -v "^$" | cat -n ;;
        3) read -r -p "IP or hostname to add: " ip
            if python3 "$ATOMATOR_ROOT/lib/settings.py" host "$ip" >/dev/null; then
                echo "$ip" >> "$HOSTS_FILE"; echo -e "${GREEN}Added: $ip${NC}"
            fi ;;
        4) read -r -p "IP or hostname to remove: " ip
            if python3 "$ATOMATOR_ROOT/lib/settings.py" host "$ip" >/dev/null; then
                cp "$HOSTS_FILE" "${HOSTS_FILE}.bak" &&
                    awk -v value="$ip" '$1 != value' "$HOSTS_FILE" > "${HOSTS_FILE}.tmp" &&
                    mv "${HOSTS_FILE}.tmp" "$HOSTS_FILE" && echo -e "${GREEN}Removed: $ip${NC}"
            fi ;;
        5) cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"; sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$HOSTS_FILE" | uniq > "${HOSTS_FILE}.tmp"; mv "${HOSTS_FILE}.tmp" "$HOSTS_FILE"; echo -e "${GREEN}Done.${NC}" ;;
        6) cp "$HOSTS_FILE" "${HOSTS_FILE}.bak"; sort -t. -k1,1n -k2,2n -k3,3n -k4,4n "$HOSTS_FILE" > "${HOSTS_FILE}.tmp"; mv "${HOSTS_FILE}.tmp" "$HOSTS_FILE"; echo -e "${GREEN}Sorted.${NC}" ;;
        7) echo "Hosts: $(grep -v "^#" "$HOSTS_FILE" | grep -v "^$" | wc -l)" ;;
        8) if [ -f "${HOSTS_FILE}.bak" ]; then cp "${HOSTS_FILE}.bak" "$HOSTS_FILE"; echo -e "${GREEN}Restored.${NC}"; else echo -e "${RED}No backup.${NC}"; fi ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
