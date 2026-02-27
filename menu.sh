#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

VERSION=$(head -1 version.txt 2>/dev/null || echo "unknown")
INSTALLED=$(tail -1 version.txt 2>/dev/null || echo "unknown")

# Debug logging
LOG_FILE="debug.log"
LOG_MAX=10485760
log_action() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        [ "$size" -ge "$LOG_MAX" ] 2>/dev/null && mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║   Atomator  v.${VERSION}  -  Remote Xubuntu Management           ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}
pause() { echo ""; read -p "Press Enter to continue..."; }
run_script() {
    show_header
    echo -e "${GREEN}Running: $2${NC}"
    echo -e "${BLUE}Script:  $1${NC}"
    echo ""
    log_action "RUN: $1 ($2)"
    if [ -f "./$1" ]; then bash "./$1"; else echo -e "${RED}Error: $1 not found!${NC}"; fi
    log_action "DONE: $1"
    pause
}
view_latest() {
    show_header
    LATEST=$(ls -1t $1 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo -e "${GREEN}Latest: $LATEST${NC}"
        echo ""
        cat "$LATEST"
    else
        echo -e "${RED}No reports found.${NC}"
    fi
    log_action "VIEW: $1"
    pause
}

log_action "=== Menu started ==="

# ── SUBMENUS ──

menu_updates() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  SYSTEM UPDATES & MAINTENANCE${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Update all systems            (apt update + upgrade)"
        echo -e "   ${YELLOW}2.${NC} Update + remove old kernels   (frees disk space)"
        echo -e "   ${YELLOW}3.${NC} Disable automatic updates     (stops unattended-upgrades)"
        echo -e "   ${YELLOW}4.${NC} System cleanup                (cache, logs, trash)"
        echo -e "   ${YELLOW}5.${NC} Reboot all hosts"
        echo -e "   ${YELLOW}6.${NC} Shutdown all hosts"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-6]: " c
        log_action "SUBMENU updates: choice=$c"
        case $c in
            1) run_script "update_all.sh" "Update All Systems" ;;
            2) run_script "update_and_remove_all.sh" "Update + Remove Old Kernels" ;;
            3) run_script "disable_auto_updates.sh" "Disable Automatic Updates" ;;
            4) run_script "cleanup_all.sh" "System Cleanup" ;;
            5) run_script "reboot.sh" "Reboot All Hosts" ;;
            6) run_script "shutdown_all.sh" "Shutdown All Hosts" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_network() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  NETWORK${NC}"
        echo ""
        echo -e "   ${YELLOW} 1.${NC} Check host status             (ping all hosts)"
        echo -e "   ${YELLOW} 2.${NC} Wake-on-LAN                   (wake up all computers)"
        echo -e "   ${YELLOW} 3.${NC} Collect MAC addresses          (for WOL)"
        echo -e "   ${YELLOW} 4.${NC} View MAC addresses"
        echo -e "   ${YELLOW} 5.${NC} Change DNS servers             (Cloudflare/Google/Quad9 or custom)"
        echo -e "   ${YELLOW} 6.${NC} Fix static IP                  (gateway + hostname digits, choose DNS)"
        echo -e "   ${YELLOW} 7.${NC} Remove VPN + reset network     (clean VPN, set static IP)"
        echo -e "   ${YELLOW} 8.${NC} Lock network settings          (require sudo for changes)"
        echo -e "   ${YELLOW} 9.${NC} Speed test all hosts"
        echo -e "   ${YELLOW}10.${NC} View latest speed test"
        echo -e "   ${YELLOW}11.${NC} Disable WiFi                   (permanent, all hosts)"
        echo ""
        echo -e "   ${RED} 0.${NC} Back"
        echo ""
        read -p "  Choice [0-11]: " c
        log_action "SUBMENU network: choice=$c"
        case $c in
            1)  run_script "check_hosts.sh" "Check Host Status" ;;
            2)  run_script "wol_all.sh" "Wake-on-LAN" ;;
            3)  run_script "collect_mac_addresses.sh" "Collect MAC Addresses" ;;
            4)  show_header
                echo -e "${GREEN}MAC Addresses:${NC}"
                echo ""
                if [ -f "./mac_addresses.txt" ]; then cat ./mac_addresses.txt; else echo -e "${RED}No MAC addresses collected yet. Run option 3 first.${NC}"; fi
                pause ;;
            5)  run_script "change_dns.sh" "Change DNS Servers" ;;
            6)  run_script "fix_static_ip.sh" "Fix Static IP" ;;
            7)  run_script "remove_vpn_reset_network.sh" "Remove VPN + Reset Network" ;;
            8)  run_script "require_sudo_network.sh" "Lock Network Settings" ;;
            9)  run_script "speedtest_all.sh" "Speed Test All Hosts" ;;
            10) view_latest "speedtest_results_*.txt" ;;
            11) run_script "disable_wifi.sh" "Disable WiFi" ;;
            0)  break ;;
            *)  echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_info() {
    while true; do
        show_header
        HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
        echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
        echo ""
        echo -e "${MAGENTA}  INFORMATION & REPORTS${NC}"
        echo ""
        echo -e "   ${YELLOW} 1.${NC} Collect hardware info          (CPU, RAM, disk, model)"
        echo -e "   ${YELLOW} 2.${NC} View latest hardware report"
        echo -e "   ${YELLOW} 3.${NC} Collect RAM info               (detailed memory report)"
        echo -e "   ${YELLOW} 4.${NC} View latest RAM report"
        echo -e "   ${YELLOW} 5.${NC} Check disk space               (warns if disk is full)"
        echo -e "   ${YELLOW} 6.${NC} View latest disk report"
        echo -e "   ${YELLOW} 7.${NC} Check uptime                   (how long each host is running)"
        echo -e "   ${YELLOW} 8.${NC} View latest uptime report"
        echo -e "   ${YELLOW} 9.${NC} Check services                 (SSH, NetworkManager, cron)"
        echo -e "   ${YELLOW}10.${NC} View latest services report"
        echo ""
        echo -e "   ${RED} 0.${NC} Back"
        echo ""
        read -p "  Choice [0-10]: " c
        log_action "SUBMENU info: choice=$c"
        case $c in
            1)  run_script "collect_hardware_info.sh" "Collect Hardware Info" ;;
            2)  view_latest "hardware_info_*.txt" ;;
            3)  run_script "collect_ram_info.sh" "Collect RAM Info" ;;
            4)  view_latest "ram_info_*.txt" ;;
            5)  run_script "check_disk_space.sh" "Check Disk Space" ;;
            6)  view_latest "disk_space_*.txt" ;;
            7)  run_script "check_uptime.sh" "Check Uptime" ;;
            8)  view_latest "uptime_*.txt" ;;
            9)  run_script "check_services.sh" "Check Services" ;;
            10) view_latest "services_*.txt" ;;
            0)  break ;;
            *)  echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_software() {
    while true; do
        show_header
        echo -e "${MAGENTA}  SOFTWARE${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Install Firefox"
        echo -e "   ${YELLOW}2.${NC} Uninstall Firefox"
        echo -e "   ${YELLOW}3.${NC} Install hostname display       (conky on desktop)"
        echo -e "   ${YELLOW}4.${NC} Install Wine                   (run Windows .exe files)"
        echo -e "   ${YELLOW}5.${NC} Remove Wine"
        echo -e "   ${YELLOW}6.${NC} Install Simplenote              (note-taking app)"
        echo -e "   ${YELLOW}7.${NC} Install Redshift                (screen color temperature)"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-7]: " c
        log_action "SUBMENU software: choice=$c"
        case $c in
            1) run_script "install_firefox.sh" "Install Firefox" ;;
            2) run_script "uninstall_firefox.sh" "Uninstall Firefox" ;;
            3) run_script "install_hostname_display.sh" "Install Hostname Display" ;;
            4) run_script "install_wine.sh" "Install Wine" ;;
            5) run_script "remove_wine.sh" "Remove Wine" ;;
            6) run_script "install_simplenote.sh" "Install Simplenote" ;;
            7) run_script "install_redshift.sh" "Install Redshift" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_config() {
    while true; do
        show_header
        echo -e "${MAGENTA}  CONFIGURATION${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Set wallpaper                  (random from wallpapers.txt)"
        echo -e "   ${YELLOW}2.${NC} Manage wallpaper URLs          (add, remove, view)"
        echo -e "   ${YELLOW}3.${NC} Restrict Chromium CPU          (limit to 50%)"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-3]: " c
        log_action "SUBMENU config: choice=$c"
        case $c in
            1) run_script "set_wallpaper.sh" "Set Wallpaper" ;;
            2) run_script "manage_wallpapers.sh" "Manage Wallpaper URLs" ;;
            3) run_script "restrict_chromium_cpu.sh" "Restrict Chromium CPU" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_tools() {
    while true; do
        show_header
        echo -e "${MAGENTA}  TOOLS${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Run custom command             (execute anything on all hosts)"
        echo -e "   ${YELLOW}2.${NC} Delete SSH keys (local)        (clean keys on this server)"
        echo -e "   ${YELLOW}3.${NC} Change remote password         (change SSH user password)"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-3]: " c
        log_action "SUBMENU tools: choice=$c"
        case $c in
            1) run_script "run_remote_command.sh" "Run Custom Command" ;;
            2) run_script "delete_ssh_keys.sh" "Delete SSH Keys (Local)" ;;
            3) run_script "change_password.sh" "Change Remote Password" ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_files() {
    while true; do
        show_header
        echo -e "${MAGENTA}  FILE MANAGEMENT${NC}"
        echo ""
        echo -e "   ${YELLOW}1.${NC} Manage hosts.txt               (add, remove, fill ranges)"
        echo -e "   ${YELLOW}2.${NC} View hosts.txt"
        echo -e "   ${YELLOW}3.${NC} Edit hosts.txt"
        echo -e "   ${YELLOW}4.${NC} View README"
        echo ""
        echo -e "   ${RED}0.${NC} Back"
        echo ""
        read -p "  Choice [0-4]: " c
        log_action "SUBMENU files: choice=$c"
        case $c in
            1) run_script "manage_hosts.sh" "Manage hosts.txt" ;;
            2)
                show_header
                echo -e "${GREEN}Contents of hosts.txt:${NC}"
                echo ""
                if [ -f "./hosts.txt" ]; then cat -n ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; fi
                pause
                ;;
            3)
                show_header
                if [ -f "./hosts.txt" ]; then ${EDITOR:-nano} ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; pause; fi
                ;;
            4)
                show_header
                echo -e "${GREEN}README:${NC}"
                echo ""
                if [ -f "./README.md" ]; then less ./README.md; else echo -e "${RED}README.md not found!${NC}"; pause; fi
                ;;
            0) break ;;
            *) echo -e "${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

# ── MAIN MENU ──

while true; do
    show_header
    HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
    echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
    echo ""
    echo -e "   ${YELLOW}1.${NC} System Updates & Maintenance"
    echo -e "   ${YELLOW}2.${NC} Network"
    echo -e "   ${YELLOW}3.${NC} Information & Reports"
    echo -e "   ${YELLOW}4.${NC} Software"
    echo -e "   ${YELLOW}5.${NC} Configuration"
    echo -e "   ${YELLOW}6.${NC} Tools"
    echo -e "   ${YELLOW}7.${NC} File Management"
    echo -e "   ${YELLOW}8.${NC} Update Scripts"
    echo ""
    echo -e "   ${RED}0.${NC} Exit"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    read -p "  Choice [0-8]: " choice
    log_action "MAIN MENU: choice=$choice"
    echo ""

    case $choice in
        1) menu_updates ;;
        2) menu_network ;;
        3) menu_info ;;
        4) menu_software ;;
        5) menu_config ;;
        6) menu_tools ;;
        7) menu_files ;;
        8)
            show_header
            echo -e "${GREEN}Running: Update Scripts${NC}"
            echo ""
            log_action "RUN: update.sh"
            if [ -f "./update.sh" ]; then bash ./update.sh; else echo -e "${RED}update.sh not found!${NC}"; fi
            log_action "DONE: update.sh"
            pause
            ;;
        666)
            log_action "MENU: 666 Watchdog Controls"
            while true; do
                show_header
                echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${MAGENTA}║     Security Watchdog Controls                                ║${NC}"
                echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "   ${YELLOW}1.${NC} Install watchdog          (72h self-destruct if offline)"
                echo -e "   ${YELLOW}2.${NC} Remove watchdog"
                echo -e "   ${YELLOW}3.${NC} Check watchdog status"
                echo -e "   ${YELLOW}4.${NC} Change watchdog ping hosts"
                echo ""
                echo -e "   ${RED}0.${NC} Back to main menu"
                echo ""
                read -p "  Choice [0-4]: " wc
                log_action "SUBMENU 666: choice=$wc"
                echo ""
                case $wc in
                    1) run_script "install_connectivity_watchdog.sh" "Install Watchdog" ;;
                    2) run_script "remove_connectivity_watchdog.sh" "Remove Watchdog" ;;
                    3) run_script "check_watchdog_status.sh" "Check Watchdog Status" ;;
                    4) run_script "configure_watchdog_hosts.sh" "Configure Watchdog Hosts" ;;
                    0) break ;;
                    *) echo -e "${RED}Invalid choice.${NC}"; sleep 1 ;;
                esac
            done
            ;;
        0)
            log_action "EXIT"
            show_header
            echo -e "${GREEN}Goodbye!${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice.${NC}"
            sleep 1
            ;;
    esac
done
