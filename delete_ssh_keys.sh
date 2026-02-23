#!/bin/bash
set +e
echo "=== Delete SSH Keys ==="
echo "Removes all SSH keys from all users and regenerates host keys."
echo ""
read -p "Delete ALL SSH keys on ALL hosts? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Deleting SSH keys..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "
        for user_home in /home/*; do
            if [ -d \"\$user_home/.ssh\" ]; then
                rm -f \"\$user_home/.ssh/id_\"* \"\$user_home/.ssh/authorized_keys\" \"\$user_home/.ssh/known_hosts\"
            fi
        done
        if [ -d /root/.ssh ]; then
            rm -f /root/.ssh/id_* /root/.ssh/authorized_keys /root/.ssh/known_hosts
        fi
        rm -f /etc/ssh/ssh_host_*
        ssh-keygen -A 2>/dev/null || dpkg-reconfigure openssh-server 2>/dev/null || true
        echo \"SSH keys deleted, host keys regenerated\"
    "' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
