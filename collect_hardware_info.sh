#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Collect Hardware Info ==="
echo "Gathers hostname, manufacturer, model, CPU, RAM, disk from all hosts."
echo ""
OUTPUT_FILE="hardware_info_$(date +%Y%m%d_%H%M%S).txt"
echo "Hardware Report - $(date)" > "$OUTPUT_FILE"
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Collecting..."
    INFO=$(sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        'echo '"$SSH_PASS"' | sudo -S bash -c "
        echo \"  Hostname:     \$(hostname)\"
        echo \"  Manufacturer: \$(dmidecode -s system-manufacturer 2>/dev/null || echo N/A)\"
        echo \"  Model:        \$(dmidecode -s system-product-name 2>/dev/null || echo N/A)\"
        echo \"  Serial:       \$(dmidecode -s system-serial-number 2>/dev/null || echo N/A)\"
        echo \"  CPU:          \$(grep -m1 \"model name\" /proc/cpuinfo | cut -d: -f2 | xargs)\"
        echo \"  Cores:        \$(nproc)\"
        echo \"  RAM:          \$(free -h | awk \"/Mem:/{print \\\$2}\") total\"
        echo \"  Disk:         \$(df -h / | awk \"NR==2{print \\\$2 \\\" total, \\\" \\\$4 \\\" free}\")\"
        echo \"  OS:           \$(lsb_release -ds 2>/dev/null || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d= -f2 | tr -d \\\"\\\")\"
        echo \"  Kernel:       \$(uname -r)\"
        echo \"  Uptime:       \$(uptime -p)\"
    "' 2>/dev/null) || true
    echo "$INFO"
    echo -e "\n$host:\n$INFO" >> "$OUTPUT_FILE"
done
echo ""
echo "Saved to: $OUTPUT_FILE"
