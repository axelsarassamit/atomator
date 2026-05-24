#!/bin/bash
BOLD='\033[1m'; DIM='\033[2m'
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'
CYAN='\033[0;36m'; MAGENTA='\033[0;35m'; WHITE='\033[1;37m'; NC='\033[0m'
BG_CYAN='\033[46m'; BG_BLUE='\033[44m'; BG_DARK='\033[100m'

VERSION=$(head -1 version.txt 2>/dev/null || echo "unknown")
INSTALLED=$(tail -1 version.txt 2>/dev/null || echo "unknown")

LOG_FILE="debug.log"
LOG_MAX=10485760
log_action() {
    if [ -f "$LOG_FILE" ]; then
        local size=$(stat -c%s "$LOG_FILE" 2>/dev/null || echo 0)
        [ "$size" -ge "$LOG_MAX" ] 2>/dev/null && mv "$LOG_FILE" "${LOG_FILE}.1"
    fi
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$LOG_FILE"
}

get_online_count() {
    local online=0
    for host in $(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | head -5); do
        ping -c 1 -W 1 "$host" &>/dev/null && online=$((online + 1))
    done &
    wait
    echo "$online"
}

show_header() {
    clear
    local HOST_COUNT=$(grep -v "^#" hosts.txt 2>/dev/null | grep -v "^$" | wc -l)
    local NOW=$(date '+%H:%M:%S')
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "     ${WHITE}${BOLD}⚡  A T O M A T O R${NC}"
    echo -e "     ${DIM}Remote Xubuntu Management System${NC}"
    echo ""
    echo -e "     ${DIM}v.${VERSION}  |  ${HOST_COUNT} hosts  |  ${NOW}${NC}"
    echo ""
    echo -e "  ${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

show_divider() {
    echo -e "  ${DIM}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

show_section() {
    echo -e "  ${CYAN}${BOLD}  $1${NC}"
}

show_subsection() {
    echo -e "  ${DIM}  -- $1 --${NC}"
}

show_item() {
    local num="$1" icon="$2" label="$3" desc="$4"
    if [ ${#num} -eq 1 ]; then
        printf "  ${YELLOW}${BOLD}   %s${NC}  ${WHITE}%s  %-28s${NC} ${DIM}%s${NC}\n" "$num" "$icon" "$label" "$desc"
    else
        printf "  ${YELLOW}${BOLD}  %s${NC}  ${WHITE}%s  %-28s${NC} ${DIM}%s${NC}\n" "$num" "$icon" "$label" "$desc"
    fi
}

show_back() {
    echo ""
    echo -e "  ${RED}${BOLD}   0${NC}  ${DIM}◄  Back${NC}"
}

show_exit() {
    echo ""
    echo -e "  ${RED}${BOLD}   0${NC}  ${DIM}⏻  Exit${NC}"
}

show_prompt() {
    echo ""
    show_divider
    echo ""
    echo -ne "  ${CYAN}❯${NC} "
}

pause() { echo ""; echo -ne "  ${DIM}Press Enter to continue...${NC}"; read; }

run_script() {
    show_header
    echo -e "  ${GREEN}${BOLD}▶ Running:${NC} $2"
    echo -e "  ${DIM}  Script:  $1${NC}"
    echo ""
    show_divider
    echo ""
    log_action "RUN: $1 ($2)"
    if [ -f "./$1" ]; then bash "./$1"; else echo -e "  ${RED}Error: $1 not found!${NC}"; fi
    log_action "DONE: $1"
    pause
}

view_latest() {
    show_header
    LATEST=$(ls -1t $1 2>/dev/null | head -1)
    if [ -n "$LATEST" ]; then
        echo -e "  ${GREEN}${BOLD}📄 Latest:${NC} $LATEST"
        echo ""
        show_divider
        echo ""
        less -FRX "$LATEST"
    else
        echo -e "  ${RED}No reports found.${NC}"
    fi
    log_action "VIEW: $1"
}

log_action "=== Menu started ==="

menu_updates() {
    while true; do
        show_header
        show_section "SYSTEM UPDATES & MAINTENANCE"
        echo ""
        show_subsection "Updates"
        show_item "1" "🔄" "Update all systems" "apt update + upgrade"
        show_item "2" "🧹" "Update + purge kernels" "frees disk space"
        show_item "3" "🚫" "Disable auto updates" "stops unattended-upgrades"
        echo ""
        show_subsection "Maintenance"
        show_item "4" "🗑️" " System cleanup" "cache, logs, trash"
        show_item "5" "♻️" " Reboot all hosts" "restart machines"
        show_item "6" "⏹️" " Shutdown all hosts" "power off machines"
        show_back
        show_prompt
        read c
        log_action "SUBMENU updates: choice=$c"
        case $c in
            1) run_script "update_all.sh" "Update All Systems" ;;
            2) run_script "update_and_remove_all.sh" "Update + Remove Old Kernels" ;;
            3) run_script "disable_auto_updates.sh" "Disable Automatic Updates" ;;
            4) run_script "cleanup_all.sh" "System Cleanup" ;;
            5) run_script "reboot.sh" "Reboot All Hosts" ;;
            6) run_script "shutdown_all.sh" "Shutdown All Hosts" ;;
            0) break ;;
            *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_network() {
    while true; do
        show_header
        show_section "NETWORK"
        echo ""
        show_subsection "Status & Wake"
        show_item "1" "📡" "Check host status" "ping all hosts"
        show_item "2" "⚡" "Wake-on-LAN" "wake up computers"
        show_item "3" "🔍" "Collect MAC addresses" "gather for WOL"
        show_item "4" "📋" "View MAC addresses" "show collected"
        echo ""
        show_subsection "DNS & IP"
        show_item "5" "🌐" "Change DNS servers" "Cloudflare/Google/custom"
        show_item "6" "📌" "Fix static IP" "gateway + hostname digits"
        show_item "7" "📶" "Disable WiFi" "permanent, all hosts"
        echo ""
        show_subsection "Security & Testing"
        show_item "8" "🔒" "Remove VPN + reset network" "clean VPN, set static"
        show_item "9" "🛡️" " Lock network settings" "require sudo"
        show_item "10" "🚀" "Speed test all hosts" "run speedtest-cli"
        show_item "11" "📊" "View latest speed test" "show recent results"
        show_item "12" "🌍" "Check internet" "HTTP + ping test"
        show_back
        show_prompt
        read c
        log_action "SUBMENU network: choice=$c"
        case $c in
            1)  run_script "check_hosts.sh" "Check Host Status" ;;
            2)  run_script "wol_all.sh" "Wake-on-LAN" ;;
            3)  run_script "collect_mac_addresses.sh" "Collect MAC Addresses" ;;
            4)  show_header
                echo -e "  ${GREEN}${BOLD}📋 MAC Addresses:${NC}"
                echo ""
                if [ -f "./mac_addresses.txt" ]; then cat ./mac_addresses.txt; else echo -e "  ${RED}No MAC addresses collected yet. Run option 3 first.${NC}"; fi
                pause ;;
            5)  run_script "change_dns.sh" "Change DNS Servers" ;;
            6)  run_script "fix_static_ip.sh" "Fix Static IP" ;;
            7)  run_script "disable_wifi.sh" "Disable WiFi" ;;
            8)  run_script "remove_vpn_reset_network.sh" "Remove VPN + Reset Network" ;;
            9)  run_script "require_sudo_network.sh" "Lock Network Settings" ;;
            10) run_script "speedtest_all.sh" "Speed Test All Hosts" ;;
            11) view_latest "speedtest_results_*.txt" ;;
            12) run_script "check_internet.sh" "Check Internet Connectivity" ;;
            0)  break ;;
            *)  echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_info() {
    while true; do
        show_header
        show_section "INFORMATION & REPORTS"
        echo ""
        show_item "1" "🖥️" " Hardware info" "CPU, RAM, disk, model"
        show_item "2" "📄" "View hardware report" "show latest"
        show_item "3" "💾" "RAM info" "detailed memory"
        show_item "4" "📄" "View RAM report" "show latest"
        show_item "5" "💿" "Disk space" "warns if full"
        show_item "6" "📄" "View disk report" "show latest"
        show_item "7" "⏱️" " Uptime" "how long running"
        show_item "8" "📄" "View uptime report" "show latest"
        show_item "9" "⚙️" " Services" "SSH, NM, cron"
        show_item "10" "📄" "View services report" "show latest"
        show_item "11" "📈" "Fleet health summary" "RAM, disk, uptime stats"
        show_back
        show_prompt
        read c
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
            11) run_script "system_info_summary.sh" "Fleet Health Summary" ;;
            0)  break ;;
            *)  echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_software() {
    while true; do
        show_header
        show_section "SOFTWARE"
        echo ""
        show_subsection "Install"
        show_item "1" "🦊" "Firefox" "default ESR browser"
        show_item "2" "🌍" "Google Chrome" "official browser"
        show_item "3" "💠" "Chromium" "open-source Chrome"
        show_item "4" "🍷" "Wine" "run Windows .exe"
        show_item "5" "📝" "Simplenote" "note-taking app"
        show_item "6" "🌅" "Redshift" "screen color temp"
        show_item "7" "📌" "Xpad" "sticky notes"
        show_item "8" "🏷️" " Hostname display" "conky overlay"
        show_item "9" "📦" "Install any package" "apt install by name"
        echo ""
        show_subsection "Remove"
        show_item "10" "❌" "Firefox" ""
        show_item "11" "❌" "Google Chrome" ""
        show_item "12" "❌" "Chromium" ""
        show_item "13" "❌" "Wine" ""
        show_item "14" "❌" "Simplenote" ""
        show_item "15" "❌" "Redshift" ""
        show_item "16" "❌" "Xpad" ""
        echo ""
        show_subsection "Fix"
        show_item "17" "🔧" "Fix hostname display" "repair/restart conky"
        show_back
        show_prompt
        read c
        log_action "SUBMENU software: choice=$c"
        case $c in
            1)  run_script "install_firefox.sh" "Install Firefox" ;;
            2)  run_script "install_chrome.sh" "Install Google Chrome" ;;
            3)  run_script "install_chromium.sh" "Install Chromium" ;;
            4)  run_script "install_wine.sh" "Install Wine" ;;
            5)  run_script "install_simplenote.sh" "Install Simplenote" ;;
            6)  run_script "install_redshift.sh" "Install Redshift" ;;
            7)  run_script "install_xpad.sh" "Install Xpad" ;;
            8)  run_script "install_hostname_display.sh" "Install Hostname Display" ;;
            9)  run_script "install_package.sh" "Install Package" ;;
            10) run_script "uninstall_firefox.sh" "Uninstall Firefox" ;;
            11) run_script "remove_chrome.sh" "Remove Google Chrome" ;;
            12) run_script "remove_chromium.sh" "Remove Chromium" ;;
            13) run_script "remove_wine.sh" "Remove Wine" ;;
            14) run_script "remove_simplenote.sh" "Remove Simplenote" ;;
            15) run_script "remove_redshift.sh" "Remove Redshift" ;;
            16) run_script "remove_xpad.sh" "Remove Xpad" ;;
            17) run_script "fix_hostname_display.sh" "Fix Hostname Display" ;;
            0)  break ;;
            *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_config() {
    while true; do
        show_header
        show_section "CONFIGURATION"
        echo ""
        show_item "1" "🎨" "Set wallpaper" "random from list"
        show_item "2" "🖼️" " Manage wallpaper URLs" "add, remove, view"
        show_item "3" "⚙️" " Restrict Chromium CPU" "limit to 50%"
        show_back
        show_prompt
        read c
        log_action "SUBMENU config: choice=$c"
        case $c in
            1) run_script "set_wallpaper.sh" "Set Wallpaper" ;;
            2) run_script "manage_wallpapers.sh" "Manage Wallpaper URLs" ;;
            3) run_script "restrict_chromium_cpu.sh" "Restrict Chromium CPU" ;;
            0) break ;;
            *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_tools() {
    while true; do
        show_header
        show_section "TOOLS"
        echo ""
        show_subsection "Remote"
        show_item "1" "💻" "Run custom command" "execute on all hosts"
        show_item "2" "🔑" "Change remote password" "update SSH password"
        show_item "3" "📂" "Copy file to all" "SCP to every host"
        show_item "4" "🔒" "Lock all screens" "instant lock"
        show_item "5" "💬" "Send message" "popup notification"
        echo ""
        show_subsection "Fix"
        show_item "6" "🗝️" " Delete SSH keys" "clean local keys"
        show_item "7" "🐌" "Fix slow sudo" "hostname in /etc/hosts"
        show_back
        show_prompt
        read c
        log_action "SUBMENU tools: choice=$c"
        case $c in
            1) run_script "run_remote_command.sh" "Run Custom Command" ;;
            2) run_script "change_password.sh" "Change Remote Password" ;;
            3) run_script "copy_file_to_all.sh" "Copy File to All Hosts" ;;
            4) run_script "lock_screens.sh" "Lock All Screens" ;;
            5) run_script "send_message.sh" "Send Message to All" ;;
            6) run_script "delete_ssh_keys.sh" "Delete SSH Keys" ;;
            7) run_script "fix_slow_sudo.sh" "Fix Slow Sudo" ;;
            0) break ;;
            *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

menu_files() {
    while true; do
        show_header
        show_section "FILE MANAGEMENT"
        echo ""
        show_item "1" "📋" "Manage hosts.txt" "add, remove, ranges"
        show_item "2" "👁️" " View hosts.txt" "display host list"
        show_item "3" "✏️" " Edit hosts.txt" "open in editor"
        show_item "4" "📖" "View README" "project documentation"
        show_item "5" "📜" "View log" "last 30 menu actions"
        show_back
        show_prompt
        read c
        log_action "SUBMENU files: choice=$c"
        case $c in
            1) run_script "manage_hosts.sh" "Manage hosts.txt" ;;
            2)
                show_header
                echo -e "  ${GREEN}${BOLD}📋 Contents of hosts.txt:${NC}"
                echo ""
                if [ -f "./hosts.txt" ]; then cat -n ./hosts.txt; else echo -e "  ${RED}hosts.txt not found!${NC}"; fi
                pause
                ;;
            3)
                show_header
                if [ -f "./hosts.txt" ]; then ${EDITOR:-nano} ./hosts.txt; else echo -e "  ${RED}hosts.txt not found!${NC}"; pause; fi
                ;;
            4)
                show_header
                if [ -f "./README.md" ]; then less ./README.md; else echo -e "  ${RED}README.md not found!${NC}"; pause; fi
                ;;
            5) run_script "view_log.sh" "View Debug Log" ;;
            0) break ;;
            *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
        esac
    done
}

# ── MAIN MENU ──

while true; do
    show_header
    show_subsection "Main Menu"
    show_item "1" "🔄" "System Updates" "update, reboot, cleanup"
    show_item "2" "🌐" "Network" "status, DNS, speed test"
    show_item "3" "📊" "Information & Reports" "hardware, disk, uptime"
    show_item "4" "📦" "Software" "install & remove apps"
    show_item "5" "⚙️" " Configuration" "wallpaper, CPU limits"
    show_item "6" "🛠️" " Tools" "remote commands, passwords"
    show_item "7" "📁" "File Management" "hosts.txt, README"
    show_item "8" "⬆️" " Update Scripts" "check for new version"
    show_exit
    show_prompt
    read choice
    log_action "MAIN MENU: choice=$choice"

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
            echo -e "  ${GREEN}${BOLD}▶ Running:${NC} Update Scripts"
            echo ""
            log_action "RUN: update.sh"
            if [ -f "./update.sh" ]; then bash ./update.sh; else echo -e "  ${RED}update.sh not found!${NC}"; fi
            log_action "DONE: update.sh"
            pause
            ;;
        666)
            log_action "MENU: 666 Watchdog Controls"
            while true; do
                show_header
                echo -e "  ${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo -e "     ${MAGENTA}${BOLD}🛡️  Security Watchdog Controls${NC}"
                echo -e "  ${MAGENTA}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
                echo ""
                show_subsection "Hosts (hosts.txt + credentials.conf)"
                show_item "1" "📥" "Install watchdog" "72h timeout if offline"
                show_item "2" "🗑️" " Remove watchdog" ""
                show_item "3" "📡" "Check watchdog status" ""
                show_item "4" "🎯" "Change ping hosts" ""
                show_item "5" "⏱️" " Change timer" "default 72h"
                echo ""
                show_subsection "Additional server (prompts for credentials)"
                show_item "6" "🖥️" " Install on extra server" "ad-hoc install"
                show_back
                show_prompt
                read wc
                log_action "SUBMENU 666: choice=$wc"
                case $wc in
                    1) run_script "install_connectivity_watchdog.sh" "Install Watchdog" ;;
                    2) run_script "remove_connectivity_watchdog.sh" "Remove Watchdog" ;;
                    3) run_script "check_watchdog_status.sh" "Check Watchdog Status" ;;
                    4) run_script "configure_watchdog_hosts.sh" "Configure Watchdog Hosts" ;;
                    5) run_script "change_watchdog_timer.sh" "Change Watchdog Timer" ;;
                    6) run_script "install_server_watchdog.sh" "Install Watchdog on Additional Server" ;;
                    0) break ;;
                    *) echo -e "  ${RED}Invalid.${NC}"; sleep 1 ;;
                esac
            done
            ;;
        0)
            log_action "EXIT"
            show_header
            echo -e "  ${GREEN}${BOLD}  Goodbye! 👋${NC}"
            echo ""
            exit 0
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${NC}"
            sleep 1
            ;;
    esac
done
