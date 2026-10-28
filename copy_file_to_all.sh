#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/runtime.sh"
runtime_init "$@"
read -r -p 'Local file: ' LOCAL_FILE || exit 0
read -r -p 'Absolute remote file path (SSH user must be able to write it): ' REMOTE_FILE || exit 0
[[ -f "$LOCAL_FILE" && ! -L "$LOCAL_FILE" && "$REMOTE_FILE" =~ ^/[A-Za-z0-9_./-]+$ && "$REMOTE_FILE" != */../* && "$REMOTE_FILE" != */ ]] || { echo 'Choose a regular local file and a remote file path without spaces or shell characters.' >&2; exit 64; }
LOCAL_FILE=$(realpath -- "$LOCAL_FILE")
run_host() { remote_copy "$1" "$LOCAL_FILE" "$REMOTE_FILE"; }
fleet_run run_host
