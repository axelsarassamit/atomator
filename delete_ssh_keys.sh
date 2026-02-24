#!/bin/bash
set +e
echo "=== Delete SSH Keys (Local) ==="
echo "Removes all SSH keys on THIS machine and regenerates host keys."
echo "This does NOT affect remote hosts."
echo ""
read -p "Delete ALL SSH keys on this machine? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for user_home in /home/*; do
    if [ -d "$user_home/.ssh" ]; then
        rm -f "$user_home/.ssh/id_"* "$user_home/.ssh/authorized_keys" "$user_home/.ssh/known_hosts"
        echo "  Cleaned: $user_home/.ssh/"
    fi
done
if [ -d /root/.ssh ]; then
    rm -f /root/.ssh/id_* /root/.ssh/authorized_keys /root/.ssh/known_hosts
    echo "  Cleaned: /root/.ssh/"
fi
rm -f /etc/ssh/ssh_host_*
ssh-keygen -A 2>/dev/null || dpkg-reconfigure openssh-server 2>/dev/null || true
echo ""
echo "SSH keys deleted, host keys regenerated."
echo "Done."
