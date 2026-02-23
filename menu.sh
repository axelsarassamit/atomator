#!/bin/bash
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; NC='\033[0m'

VERSION=$(head -1 version.txt 2>/dev/null || echo "unknown")
INSTALLED=$(tail -1 version.txt 2>/dev/null || echo "unknown")

show_header() {
    clear
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║         Remote Xubuntu Management  v${VERSION}                       ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}
pause() { echo ""; read -p "Press Enter to continue..."; }
run_script() {
    show_header
    echo -e "${GREEN}Running: $2${NC}"
    echo -e "${BLUE}Script:  $1${NC}"
    echo ""
    if [ -f "./$1" ]; then bash "./$1"; else echo -e "${RED}Error: $1 not found!${NC}"; fi
    pause
}

while true; do
    show_header
    HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
    echo -e "${BLUE}  Hosts: ${HOST_COUNT}  |  Installed: ${INSTALLED}${NC}"
    echo ""

    echo -e "${MAGENTA}  SYSTEM UPDATES${NC}"
    echo -e "   ${YELLOW} 1.${NC} Update all systems            (apt update + upgrade)"
    echo -e "   ${YELLOW} 2.${NC} Update + remove old kernels   (frees disk space)"
    echo -e "   ${YELLOW} 3.${NC} Disable automatic updates     (stops unattended-upgrades)"
    echo ""
    echo -e "${MAGENTA}  SYSTEM MAINTENANCE${NC}"
    echo -e "   ${YELLOW} 4.${NC} System cleanup                (cache, logs, trash)"
    echo -e "   ${YELLOW} 5.${NC} Reboot all hosts"
    echo -e "   ${YELLOW} 6.${NC} Shutdown all hosts"
    echo ""
    echo -e "${MAGENTA}  NETWORK${NC}"
    echo -e "   ${YELLOW} 7.${NC} Check host status             (ping all hosts)"
    echo -e "   ${YELLOW} 8.${NC} Wake-on-LAN                   (wake up all computers)"
    echo -e "   ${YELLOW} 9.${NC} Collect MAC addresses          (for WOL)"
    echo -e "   ${YELLOW}10.${NC} Change DNS servers             (Cloudflare + Google + Quad9)"
    echo -e "   ${YELLOW}11.${NC} Fix static IP                  (set current IP as permanent)"
    echo -e "   ${YELLOW}12.${NC} Remove VPN + reset network     (clean VPN, set static IP)"
    echo -e "   ${YELLOW}13.${NC} Lock network settings          (require sudo for changes)"
    echo -e "   ${YELLOW}14.${NC} Speed test all hosts"
    echo -e "   ${YELLOW}15.${NC} Disable WiFi                   (permanent, all hosts)"
    echo ""
    echo -e "${MAGENTA}  INFORMATION${NC}"
    echo -e "   ${YELLOW}16.${NC} Collect hardware info          (CPU, RAM, disk, model)"
    echo -e "   ${YELLOW}17.${NC} Collect RAM info               (detailed memory report)"
    echo -e "   ${YELLOW}18.${NC} Check disk space               (warns if disk is full)"
    echo -e "   ${YELLOW}19.${NC} Check uptime                   (how long each host is running)"
    echo -e "   ${YELLOW}20.${NC} Check services                 (SSH, NetworkManager, cron)"
    echo ""
    echo -e "${MAGENTA}  SOFTWARE${NC}"
    echo -e "   ${YELLOW}21.${NC} Install Firefox"
    echo -e "   ${YELLOW}22.${NC} Uninstall Firefox"
    echo -e "   ${YELLOW}23.${NC} Install hostname display       (conky on desktop)"
    echo -e "   ${YELLOW}24.${NC} Install Wine                   (run Windows .exe files)"
    echo -e "   ${YELLOW}25.${NC} Remove Wine"
    echo ""
    echo -e "${MAGENTA}  CONFIGURATION${NC}"
    echo -e "   ${YELLOW}26.${NC} Set wallpaper                  (random from wallpapers.txt)"
    echo -e "   ${YELLOW}27.${NC} Restrict Chromium CPU          (limit to 50%)"
    echo ""
    echo -e "${MAGENTA}  TOOLS${NC}"
    echo -e "   ${YELLOW}28.${NC} Run custom command             (execute anything on all hosts)"
    echo -e "   ${YELLOW}29.${NC} Delete all SSH keys"
    echo ""
    echo -e "${MAGENTA}  FILE MANAGEMENT${NC}"
    echo -e "   ${YELLOW}30.${NC} Manage hosts.txt               (add, remove, fill ranges)"
    echo -e "   ${YELLOW}31.${NC} View hosts.txt"
    echo -e "   ${YELLOW}32.${NC} Edit hosts.txt"
    echo ""
    echo -e "   ${YELLOW}33.${NC} Update scripts                 (install new version from /root/)"
    echo -e "   ${RED} 0.${NC} Exit"
    echo ""
    echo -e "${CYAN}══════════════════════════════════════════════════════════════════${NC}"
    read -p "  Choice [0-33]: " choice
    echo ""

    case $choice in
        1)  run_script "update_all.sh" "Update All Systems" ;;
        2)  run_script "update_and_remove_all.sh" "Update + Remove Old Kernels" ;;
        3)  run_script "disable_auto_updates.sh" "Disable Automatic Updates" ;;
        4)  run_script "cleanup_all.sh" "System Cleanup" ;;
        5)  run_script "reboot.sh" "Reboot All Hosts" ;;
        6)  run_script "shutdown_all.sh" "Shutdown All Hosts" ;;
        7)  run_script "check_hosts.sh" "Check Host Status" ;;
        8)  run_script "wol_all.sh" "Wake-on-LAN" ;;
        9)  run_script "collect_mac_addresses.sh" "Collect MAC Addresses" ;;
        10) run_script "change_dns.sh" "Change DNS Servers" ;;
        11) run_script "fix_static_ip.sh" "Fix Static IP" ;;
        12) run_script "remove_vpn_reset_network.sh" "Remove VPN + Reset Network" ;;
        13) run_script "require_sudo_network.sh" "Lock Network Settings" ;;
        14) run_script "speedtest_all.sh" "Speed Test All Hosts" ;;
        15) run_script "disable_wifi.sh" "Disable WiFi" ;;
        16) run_script "collect_hardware_info.sh" "Collect Hardware Info" ;;
        17) run_script "collect_ram_info.sh" "Collect RAM Info" ;;
        18) run_script "check_disk_space.sh" "Check Disk Space" ;;
        19) run_script "check_uptime.sh" "Check Uptime" ;;
        20) run_script "check_services.sh" "Check Services" ;;
        21) run_script "install_firefox.sh" "Install Firefox" ;;
        22) run_script "uninstall_firefox.sh" "Uninstall Firefox" ;;
        23) run_script "install_hostname_display.sh" "Install Hostname Display" ;;
        24) run_script "install_wine.sh" "Install Wine" ;;
        25) run_script "remove_wine.sh" "Remove Wine" ;;
        26) run_script "set_wallpaper.sh" "Set Wallpaper" ;;
        27) run_script "restrict_chromium_cpu.sh" "Restrict Chromium CPU" ;;
        28) run_script "run_remote_command.sh" "Run Custom Command" ;;
        29) run_script "delete_ssh_keys.sh" "Delete SSH Keys" ;;
        30) run_script "manage_hosts.sh" "Manage hosts.txt" ;;
        31)
            show_header
            echo -e "${GREEN}Contents of hosts.txt:${NC}"
            echo ""
            if [ -f "./hosts.txt" ]; then cat -n ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; fi
            pause
            ;;
        32)
            show_header
            if [ -f "./hosts.txt" ]; then ${EDITOR:-nano} ./hosts.txt; else echo -e "${RED}hosts.txt not found!${NC}"; pause; fi
            ;;
        33)
            show_header
            echo -e "${GREEN}Running: Update Scripts${NC}"
            echo ""
            if [ -f "./update.sh" ]; then sudo bash ./update.sh; else echo -e "${RED}update.sh not found!${NC}"; fi
            pause
            ;;
        666)
            while true; do
                show_header
                echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${MAGENTA}║     Security Watchdog Controls                                ║${NC}"
                echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo -e "   ${YELLOW}1.${NC} Install watchdog          (72h self-destruct if offline)"
                echo -e "   ${YELLOW}2.${NC} Remove watchdog"
                echo -e "   ${YELLOW}3.${NC} Check watchdog status"
                echo ""
                echo -e "   ${RED}0.${NC} Back to main menu"
                echo ""
                read -p "  Choice [0-3]: " wc
                echo ""
                case $wc in
                    1) run_script "install_connectivity_watchdog.sh" "Install Watchdog" ;;
                    2) run_script "remove_connectivity_watchdog.sh" "Remove Watchdog" ;;
                    3) run_script "check_watchdog_status.sh" "Check Watchdog Status" ;;
                    0) break ;;
                    *) echo -e "${RED}Invalid choice.${NC}"; sleep 1 ;;
                esac
            done
            ;;
        0)
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
