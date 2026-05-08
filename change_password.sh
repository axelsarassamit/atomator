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
HOSTS=($(grep -v "^#" hosts.txt | grep -v "^$"))
TOTAL=${#HOSTS[@]}
echo "This will change the password for '$SSH_USER' on $TOTAL hosts."
read -p "Are you sure? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then echo "Cancelled."; exit 0; fi
echo ""
START_TIME=$(date +%s)
MAX_JOBS=${MAX_PARALLEL:-5}
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

change_pass() {
    local host="$1" idx="$2"
    sshpass -p "$SSH_PASS" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=10 "$SSH_USER"@"$host" \
        "echo $SSH_PASS | sudo -S bash -c 'printf \"%s:%s\" \"$SSH_USER\" \"$NEW_PASS\" | chpasswd'" &>/dev/null
    [ $? -eq 0 ] && echo "OK" > "$TMPDIR/$idx" || echo "FAIL" > "$TMPDIR/$idx"
}

for i in "${!HOSTS[@]}"; do
    change_pass "${HOSTS[$i]}" "$i" &
    while [ $(jobs -r | wc -l) -ge $MAX_JOBS ]; do sleep 0.3; done
done
wait

SUCCESS=0; FAILED=0
for i in "${!HOSTS[@]}"; do
    if [ -f "$TMPDIR/$i" ] && grep -q "OK" "$TMPDIR/$i"; then
        echo -e "  \033[0;32m[OK]\033[0m     ${HOSTS[$i]}"
        SUCCESS=$((SUCCESS + 1))
    else
        echo -e "  \033[0;31m[FAILED]\033[0m ${HOSTS[$i]}"
        FAILED=$((FAILED + 1))
    fi
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
ELAPSED=$(( $(date +%s) - START_TIME ))
echo ""
echo "Done in ${ELAPSED}s."
