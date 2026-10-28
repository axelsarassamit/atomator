#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi
set -euo pipefail
BUNDLE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
TARGET=/remote_tools
SKIP_DEPS=0
YES=0
while (($#)); do
    case "$1" in
        --target) [[ $# -ge 2 ]] || exit 64; TARGET=$2; shift 2;;
        --skip-dependencies) SKIP_DEPS=1; shift;;
        --yes) YES=1; shift;;
        *) echo "Unknown option: $1" >&2; exit 64;;
    esac
done
python3 "$BUNDLE/lib/bundle.py" validate --source "$BUNDLE"
echo "Install destination: $TARGET"
if ((!YES)); then
    read -r -p 'Install this configured bundle? (yes/no): ' answer || exit 0
    [[ "$answer" == yes ]] || exit 0
fi
if ((!SKIP_DEPS)); then
    ((EUID == 0)) || { echo 'Dependency installation requires root.' >&2; exit 1; }
    apt-get update -qq
    apt-get install -y openssh-client sshpass wakeonlan bc curl python3 coreutils util-linux git
fi
python3 "$BUNDLE/lib/bundle.py" install --source "$BUNDLE" --target "$TARGET"
if [[ "$TARGET" == /remote_tools && "$EUID" == 0 ]]; then
    launcher=$(mktemp /root/.atomator-start.XXXXXX)
    printf '%s\n' '#!/bin/bash' 'exec bash /remote_tools/run-configured.sh menu.sh "$@"' > "$launcher"
    chmod 700 "$launcher"
    mv -- "$launcher" /root/start.sh
fi
echo "Start: bash $TARGET/run-configured.sh menu.sh"
