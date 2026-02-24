#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; NC='\033[0m'
WALLPAPER_FILE="wallpapers.txt"
if [ ! -f "$WALLPAPER_FILE" ]; then
    touch "$WALLPAPER_FILE"
    echo -e "${YELLOW}Created empty $WALLPAPER_FILE${NC}"
fi
while true; do
    echo ""
    echo -e "${CYAN}=== Manage Wallpapers ===${NC}"
    TOTAL=$(grep -v "^#" "$WALLPAPER_FILE" 2>/dev/null | grep -v "^$" | wc -l | tr -d ' ')
    echo -e "${YELLOW}  URLs loaded: ${TOTAL}${NC}"
    echo ""
    echo -e "${YELLOW}1.${NC} View all URLs"
    echo -e "${YELLOW}2.${NC} Add a URL"
    echo -e "${YELLOW}3.${NC} Remove a URL"
    echo -e "${YELLOW}4.${NC} Remove all URLs"
    echo -e "${YELLOW}5.${NC} Edit wallpapers.txt"
    echo -e "${YELLOW}0.${NC} Back"
    echo ""
    read -p "Choice [0-5]: " choice
    echo ""
    case $choice in
        1) if [ "$TOTAL" -eq 0 ]; then echo -e "${RED}No wallpaper URLs found.${NC}"; else echo -e "${GREEN}Wallpaper URLs:${NC}"; echo ""; grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | cat -n; fi ;;
        2) echo -ne "${YELLOW}URL to add: ${NC}"; read url; if [ -z "$url" ]; then echo -e "${RED}No URL entered.${NC}"; else echo "$url" >> "$WALLPAPER_FILE"; echo -e "${GREEN}Added: $url${NC}"; fi ;;
        3) if [ "$TOTAL" -eq 0 ]; then echo -e "${RED}No URLs to remove.${NC}"; else echo -e "${GREEN}Current URLs:${NC}"; echo ""; grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | cat -n; echo ""; echo -ne "${YELLOW}Line number to remove (or 0 to cancel): ${NC}"; read num; if [ "$num" = "0" ] || [ -z "$num" ]; then echo "Cancelled."; else URL=$(grep -v "^#" "$WALLPAPER_FILE" | grep -v "^$" | sed -n "${num}p"); if [ -n "$URL" ]; then cp "$WALLPAPER_FILE" "${WALLPAPER_FILE}.bak"; grep -vF "$URL" "$WALLPAPER_FILE" > "${WALLPAPER_FILE}.tmp"; mv "${WALLPAPER_FILE}.tmp" "$WALLPAPER_FILE"; echo -e "${GREEN}Removed: $URL${NC}"; else echo -e "${RED}Invalid line number.${NC}"; fi; fi; fi ;;
        4) read -p "Remove ALL wallpaper URLs? (yes/no): " confirm; if [ "$confirm" = "yes" ]; then cp "$WALLPAPER_FILE" "${WALLPAPER_FILE}.bak"; > "$WALLPAPER_FILE"; echo -e "${GREEN}All URLs removed. Backup saved.${NC}"; else echo "Cancelled."; fi ;;
        5) ${EDITOR:-nano} "$WALLPAPER_FILE" ;;
        0) break ;;
        *) echo -e "${RED}Invalid.${NC}" ;;
    esac
done
