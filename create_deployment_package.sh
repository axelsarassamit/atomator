#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
OUTPUT=${1:-"$PWD/atomator-$(date -u +%Y%m%dT%H%M%SZ).tar.gz"}
exec python3 "$ROOT/lib/bundle.py" package --source "$ROOT" --output "$OUTPUT"
