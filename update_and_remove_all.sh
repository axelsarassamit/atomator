#!/bin/bash
set +e
echo "=== Update & Remove Old Kernels ==="
echo "Updates all systems and purges old kernel packages to free disk space."
echo ""
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Updating + purging old kernels..."
    sshpass -p 'sweetcom' ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 sweetagent@"$host" \
        'echo sweetcom | sudo -S bash -c "DEBIAN_FRONTEND=noninteractive apt-get update -qq && DEBIAN_FRONTEND=noninteractive apt-get upgrade -y -o Dpkg::Options::=--force-confold && DEBIAN_FRONTEND=noninteractive apt-get autoremove -y --purge && apt-get autoclean -y"' 2>&1 && echo "[$host] OK" || echo "[$host] FAILED"
done
echo ""
echo "Done."
