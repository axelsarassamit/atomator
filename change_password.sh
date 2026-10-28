#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -s -p 'New password: ' NEW_PASS || exit 0
echo
read -r -s -p 'Confirm password: ' CONFIRM_PASS || exit 0
echo
[[ -n "$NEW_PASS" && "$NEW_PASS" == "$CONFIRM_PASS" && "$NEW_PASS" != *:* ]] || { echo 'Passwords must match, be nonempty and contain no colon.' >&2; exit 64; }
read -r -p 'Change password on the selected hosts? (yes/no): ' answer || exit 0
[[ "$answer" == yes ]] || exit 0
rotate_host() {
    # Data travels over stdin, never in the remote shell command or process arguments.
    printf '%s:%s\n' "$SSH_USER" "$NEW_PASS" | remote_input "$1" 'sudo -n chpasswd'
}
fleet_run rotate_host
unset NEW_PASS CONFIRM_PASS
echo 'Saved credentials were preserved. Use results.tsv to reconcile each host before changing local credentials.'
