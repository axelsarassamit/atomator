#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
set -euo pipefail
echo 'Using the canonical bundle installer.'
exec bash "$(dirname -- "${BASH_SOURCE[0]}")/quick_install.sh" "$@"
