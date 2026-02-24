#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
CONFIG_FILE="watchdog_hosts.conf"
if [ ! -f "$CONFIG_FILE" ]; then
    cat > "$CONFIG_FILE" << 'DEFAULTS'
HOST_1=192.168.1.242
HOST_2=ntp.sweetserver.wan
HOST_3=
DEFAULTS
    chmod 600 "$CONFIG_FILE"
    echo -e "${YELLOW}Created $CONFIG_FILE with defaults.${NC}"
fi
source "$CONFIG_FILE" 2>/dev/null
while true; do
    echo ""
    echo -e "${CYAN}=== Configure Watchdog Ping Hosts ===${NC}"
    echo ""
    echo -e "  Host 1: ${GREEN}${HOST_1:-empty}${NC}"
    echo -e "  Host 2: ${GREEN}${HOST_2:-empty}${NC}"
    echo -e "  Host 3: ${GREEN}${HOST_3:-empty}${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Change Host 1"
    echo -e "  ${YELLOW}2.${NC} Change Host 2"
    echo -e "  ${YELLOW}3.${NC} Change Host 3"
    echo -e "  ${YELLOW}4.${NC} Test ping all hosts"
    echo -e "  ${YELLOW}5.${NC} Save and reinstall watchdog"
    echo -e "  ${YELLOW}0.${NC} Back"
    echo ""
    read -p "  Choice [0-5]: " choice
    echo ""
    case $choice in
        1) read -p "  New Host 1 (IP or hostname): " new_host; if [ -n "$new_host" ]; then HOST_1="$new_host"; echo -e "${GREEN}Host 1 set to: $HOST_1${NC}"; fi ;;
        2) read -p "  New Host 2 (IP or hostname): " new_host; if [ -n "$new_host" ]; then HOST_2="$new_host"; echo -e "${GREEN}Host 2 set to: $HOST_2${NC}"; fi ;;
        3) read -p "  New Host 3 (IP or hostname, empty to clear): " new_host; HOST_3="$new_host"; if [ -n "$HOST_3" ]; then echo -e "${GREEN}Host 3 set to: $HOST_3${NC}"; else echo -e "${YELLOW}Host 3 cleared.${NC}"; fi ;;
        4)
            echo "Testing hosts..."
            for h in "$HOST_1" "$HOST_2" "$HOST_3"; do
                [ -z "$h" ] && continue
                if ping -c 1 -W 2 "$h" &>/dev/null; then echo -e "  ${GREEN}[OK]${NC} $h"; else echo -e "  ${RED}[FAIL]${NC} $h"; fi
            done
            ;;
        5)
            COUNT=0
            [ -n "$HOST_1" ] && COUNT=$((COUNT + 1))
            [ -n "$HOST_2" ] && COUNT=$((COUNT + 1))
            [ -n "$HOST_3" ] && COUNT=$((COUNT + 1))
            if [ $COUNT -lt 2 ]; then
                echo -e "${RED}Minimum 2 hosts required! Currently: $COUNT${NC}"
            else
                cat > "$CONFIG_FILE" << SAVECONF
HOST_1=$HOST_1
HOST_2=$HOST_2
HOST_3=$HOST_3
SAVECONF
                chmod 600 "$CONFIG_FILE"
                echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
                echo ""
                read -p "  Reinstall watchdog with new hosts? (yes/no): " confirm
                if [ "$confirm" = "yes" ]; then
                    if [ -f "./install_connectivity_watchdog.sh" ]; then bash ./install_connectivity_watchdog.sh; else echo -e "${RED}install_connectivity_watchdog.sh not found!${NC}"; fi
                fi
            fi
            ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
