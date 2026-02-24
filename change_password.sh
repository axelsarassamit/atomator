#!/bin/bash
set +e
source ./credentials.conf 2>/dev/null || { echo "ERROR: credentials.conf not found!"; exit 1; }
echo "=== Change Remote Password ==="
echo "Changes the password for $SSH_USER on all remote hosts."
echo ""
echo -ne "New password: "
read -s NEW_PASS
echo ""
echo -ne "Confirm password: "
read -s CONFIRM_PASS
echo ""
echo ""
if [ -z "$NEW_PASS" ]; then echo "No password entered."; exit 1; fi
if [ "$NEW_PASS" != "$CONFIRM_PASS" ]; then echo "Passwords do not match!"; exit 1; fi
echo "This will change the password for '$SSH_USER' on ALL hosts."
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
SUCCESS=0; FAILED=0
for host in $(grep -v "^#" hosts.txt | grep -v "^$"); do
    echo "[$host] Changing password..."
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c 'printf \"%s:%s\" \"$SSH_USER\" \"$NEW_PASS\" | chpasswd'" 2>&1 && {
        echo "[$host] OK"
        SUCCESS=$((SUCCESS + 1))
    } || {
        echo "[$host] FAILED"
        FAILED=$((FAILED + 1))
    }
done
echo ""
echo "Results: $SUCCESS OK, $FAILED FAILED"
if [ $SUCCESS -gt 0 ]; then
    cp credentials.conf credentials.conf.bak
    sed -i "s/^SSH_PASS=.*/SSH_PASS=$NEW_PASS/" credentials.conf
    echo ""
    echo "credentials.conf updated with new password."
    echo "Old credentials backed up to credentials.conf.bak"
fi
echo ""
echo "Done."
