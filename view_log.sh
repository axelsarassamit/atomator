#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")"
if [[ -f debug.log ]]; then
    tail -n 100 -- debug.log
else
    echo 'No debug.log yet.'
fi
echo 'Per-host results and errors are stored under reports/.'
