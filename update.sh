#!/bin/bash
set +e

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; CYAN='\033[0;36m'; DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'
TARGET_DIR="/remote_tools"
REPO_OWNER="axelsarassamit"
REPO_NAME="atomator"
BRANCH="main"
RAW_BASE="https://raw.githubusercontent.com/${REPO_OWNER}/${REPO_NAME}/${BRANCH}"
API_BASE="https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}"

echo -e "${CYAN}${BOLD}=== Atomator - Update Scripts ===${NC}"
echo ""

if [ -f "$TARGET_DIR/version.txt" ]; then
    CURRENT=$(head -1 "$TARGET_DIR/version.txt")
    INSTALLED=$(tail -1 "$TARGET_DIR/version.txt")
    echo -e "  Current version:   ${GREEN}v.${CURRENT}${NC}  (installed ${INSTALLED})"
else
    CURRENT="unknown"
    echo -e "  Current version:   ${RED}unknown${NC}"
fi
echo ""

echo -e "  Checking for latest version..."
REMOTE_VERSION=$(curl -sL "${RAW_BASE}/version.txt" 2>/dev/null | head -1)
if [ -z "$REMOTE_VERSION" ]; then
    echo -e "  ${RED}Could not reach GitHub. Check your internet connection.${NC}"
    exit 1
fi
echo -e "  Latest version:    ${YELLOW}v.${REMOTE_VERSION}${NC}"
echo ""

if [ "$CURRENT" = "$REMOTE_VERSION" ]; then
    echo -e "  ${GREEN}You are already on the latest version.${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Reinstall/refresh all scripts anyway"
    echo -e "  ${YELLOW}2.${NC} Revert to a previous local version"
    echo -e "  ${RED}0.${NC} Cancel"
    echo ""
    read -p "  Choice [0-2]: " update_choice
    case $update_choice in
        1) ;;
        2)
            echo ""
            echo -e "${CYAN}Available local versions:${NC}"
            echo ""
            UPDATE_FILES=$(ls -1 "$TARGET_DIR"/updates/update_v*.sh 2>/dev/null | sort -V)
            if [ -z "$UPDATE_FILES" ]; then
                echo -e "${RED}No previous versions found.${NC}"
                exit 1
            fi
            i=1
            declare -a VERSION_FILES
            while IFS= read -r f; do
                FNAME=$(basename "$f")
                FVER=$(echo "$FNAME" | sed 's/update_v\.//;s/update_v//;s/\.sh$//')
                if [ "$FVER" = "$CURRENT" ]; then
                    echo -e "  ${YELLOW}${i}.${NC} ${FNAME}  ${GREEN}<-- current${NC}"
                else
                    echo -e "  ${YELLOW}${i}.${NC} ${FNAME}"
                fi
                VERSION_FILES[$i]="$f"
                i=$((i + 1))
            done <<< "$UPDATE_FILES"
            echo ""
            read -p "  Select version [1-$((i-1))]: " ver_choice
            if [ -z "$ver_choice" ] || [ "$ver_choice" -lt 1 ] 2>/dev/null || [ "$ver_choice" -ge "$i" ] 2>/dev/null; then
                echo "Cancelled."; exit 0
            fi
            echo ""
            echo "Running installer..."
            bash "${VERSION_FILES[$ver_choice]}"
            for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
                [ -f "/root/${f}.backup" ] && [ ! -f "$TARGET_DIR/$f" ] && cp "/root/${f}.backup" "$TARGET_DIR/$f"
            done
            echo -e "${GREEN}Reverted.${NC}"
            exit 0
            ;;
        *) echo "Cancelled."; exit 0 ;;
    esac
else
    echo -e "  Update available: ${GREEN}v.${CURRENT}${NC} -> ${YELLOW}v.${REMOTE_VERSION}${NC}"
    echo ""
    read -p "  Download and install? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
fi

echo ""

echo "Backing up config files..."
for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "$TARGET_DIR/$f" ]; then
        cp "$TARGET_DIR/$f" "/root/${f}.backup"
    fi
done
echo ""

echo "Fetching file list from GitHub..."
FILE_LIST=$(curl -sL "${API_BASE}/contents?ref=${BRANCH}" -H "Accept: application/vnd.github.v3+json" 2>/dev/null)

if echo "$FILE_LIST" | grep -q '"name"'; then
    SCRIPTS=$(echo "$FILE_LIST" | grep '"name"' | grep '\.sh"' | sed 's/.*"name": "//;s/".*//')
else
    echo -e "  ${YELLOW}API rate limited. Using known file list...${NC}"
    SCRIPTS="check_disk_space.sh check_hosts.sh check_services.sh check_uptime.sh
change_dns.sh change_password.sh change_watchdog_timer.sh
cleanup_all.sh collect_hardware_info.sh collect_mac_addresses.sh collect_ram_info.sh
configure_watchdog_hosts.sh check_watchdog_status.sh
disable_auto_updates.sh disable_wifi.sh
fix_hostname_display.sh fix_slow_sudo.sh fix_static_ip.sh
install_chrome.sh install_chromium.sh install_connectivity_watchdog.sh
install_firefox.sh install_hostname_display.sh install_redshift.sh
install_server_watchdog.sh install_simplenote.sh install_wine.sh install_xpad.sh
manage_hosts.sh manage_wallpapers.sh menu.sh
reboot.sh remove_chrome.sh remove_chromium.sh remove_connectivity_watchdog.sh
remove_redshift.sh remove_simplenote.sh remove_vpn_reset_network.sh
remove_wine.sh remove_xpad.sh require_sudo_network.sh restrict_chromium_cpu.sh
run_remote_command.sh set_wallpaper.sh shutdown_all.sh speedtest_all.sh
uninstall_firefox.sh update.sh update_all.sh update_and_remove_all.sh wol_all.sh"
fi

OTHER_FILES="CHANGELOG.md README.md version.txt"

TOTAL=$(echo "$SCRIPTS" | wc -w)
TOTAL=$((TOTAL + 3))
COUNT=0
FAILED=0

echo "Downloading $TOTAL files..."
echo ""

cd "$TARGET_DIR" || exit 1

for file in $SCRIPTS; do
    COUNT=$((COUNT + 1))
    echo -ne "  [$COUNT/$TOTAL] $file... "
    curl -sL "${RAW_BASE}/${file}" -o "$file" 2>/dev/null
    if [ -s "$file" ] && ! head -1 "$file" | grep -q "^{" && ! head -1 "$file" | grep -q "rate limit"; then
        chmod +x "$file"
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        rm -f "$file"
        FAILED=$((FAILED + 1))
    fi
done

for file in $OTHER_FILES; do
    COUNT=$((COUNT + 1))
    echo -ne "  [$COUNT/$TOTAL] $file... "
    curl -sL "${RAW_BASE}/${file}" -o "$file" 2>/dev/null
    if [ -s "$file" ] && ! head -1 "$file" | grep -q "rate limit"; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED${NC}"
        rm -f "$file"
        FAILED=$((FAILED + 1))
    fi
done

echo ""

for f in hosts.txt mac_addresses.txt wallpapers.txt credentials.conf watchdog_hosts.conf; do
    if [ -f "/root/${f}.backup" ]; then
        cp "/root/${f}.backup" "$TARGET_DIR/$f"
    fi
done

echo -e "${GREEN}${BOLD}Update complete!${NC}"
echo -e "  Version: ${YELLOW}v.$(head -1 version.txt 2>/dev/null)${NC}"
echo -e "  Files:   $((COUNT - FAILED)) OK, $FAILED failed"
echo ""
echo -e "${DIM}  Config files preserved (hosts.txt, credentials.conf, etc.)${NC}"
