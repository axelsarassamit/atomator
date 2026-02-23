#!/bin/bash
set +e
echo "=== Install Wine ==="
echo "Installs Wine to run Windows .exe files."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Installing Wine (takes a while)..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        dpkg --add-architecture i386 2>/dev/null || true
        DEBIAN_FRONTEND=noninteractive apt-get update -qq
        DEBIAN_FRONTEND=noninteractive apt-get install -y wine wine64 wine32 winetricks 2>/dev/null || true
        echo \"Wine installed\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done. Run .exe files with: wine program.exe"
