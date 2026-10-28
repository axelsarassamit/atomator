#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BUNDLE=''
DOWNLOAD=0
YES=0
TARGET=$ROOT
while (($#)); do
    case "$1" in
        --bundle) [[ $# -ge 2 ]] || exit 64; BUNDLE=$2; shift 2;;
        --target) [[ $# -ge 2 ]] || exit 64; TARGET=$2; shift 2;;
        --download) DOWNLOAD=1; shift;;
        --yes) YES=1; shift;;
        *) echo "Unknown option: $1" >&2; exit 64;;
    esac
done
if ((DOWNLOAD)); then
    [[ -z "$BUNDLE" ]] || { echo 'Choose --bundle or --download.' >&2; exit 64; }
    args=(--target "$TARGET")
    ((YES)) && args+=(--yes)
    exec python3 "$ROOT/lib/update_bundle.py" "${args[@]}"
fi
if [[ -z "$BUNDLE" ]]; then
    echo 'Update or rollback using a configured bundle directory.'
    echo "Previous installations: ${TARGET}.backups/"
    read -r -p 'Bundle directory (empty to cancel): ' BUNDLE || exit 0
    [[ -n "$BUNDLE" ]] || exit 0
fi
BUNDLE=$(cd -- "$BUNDLE" && pwd)
python3 "$ROOT/lib/bundle.py" validate --source "$BUNDLE"
args=(--target "$TARGET" --skip-dependencies)
((YES)) && args+=(--yes)
if bash "$BUNDLE/quick_install.sh" "${args[@]}"; then
    echo 'Update complete.'
else
    rc=$?
    echo 'Update failed. Inspect the error above and the preserved installation.' >&2
    exit "$rc"
fi
