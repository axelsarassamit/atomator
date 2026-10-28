#!/bin/bash
if [[ "${SITE_CONFIGURATION_CONFIRMED:-}" != 1 ]]; then
    echo 'No site configured. Use configure_site.py first.' >&2
    exit 64
fi

ATOMATOR_ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd) || exit 1
cd -- "$ATOMATOR_ROOT" || exit 1
umask 077

runtime_credentials() {
    local parsed
    parsed=$(mktemp) || return 1
    if ! python3 "$ATOMATOR_ROOT/lib/settings.py" credentials "$ATOMATOR_ROOT/credentials.conf" > "$parsed"; then
        rm -f -- "$parsed"; return 64
    fi
    local values=()
    mapfile -d '' -t values < "$parsed"
    rm -f -- "$parsed"
    SSH_USER=${SSH_USER:-${values[0]}}
    # An explicitly empty environment value selects keys/agent, including the
    # additional-server prompt's empty-password option.
    if [[ ! ${SSH_PASSWORD+x} ]]; then
        SSH_PASSWORD=${SSH_PASS-${values[1]:-${values[2]}}}
    fi
    SSH_IDENTITY_FILE=${SSH_IDENTITY_FILE:-${values[3]}}
    SSH_PORT=${SSH_PORT:-${values[4]:-22}}
    [[ "$SSH_USER" =~ ^[a-zA-Z_][a-zA-Z0-9_.-]*\$?$ ]] || { echo 'Set a valid SSH_USER in credentials.conf.' >&2; return 64; }
    [[ "$SSH_PORT" =~ ^[0-9]{1,5}$ ]] && ((10#$SSH_PORT > 0 && 10#$SSH_PORT <= 65535)) || { echo 'Invalid SSH_PORT.' >&2; return 64; }
    SSH_PORT=$((10#$SSH_PORT))
    SSH_OPTIONS=(-o StrictHostKeyChecking=yes -o "UserKnownHostsFile=${ATOMATOR_KNOWN_HOSTS:-$ATOMATOR_ROOT/known_hosts}"
        -o ConnectTimeout=10 -o ServerAliveInterval=15 -o ServerAliveCountMax=3 -o LogLevel=ERROR)
    if [[ -n "$SSH_IDENTITY_FILE" ]]; then
        [[ -f "$SSH_IDENTITY_FILE" ]] || { echo 'SSH identity file not found.' >&2; return 64; }
        SSH_OPTIONS+=(-i "$SSH_IDENTITY_FILE" -o IdentitiesOnly=yes)
    fi
    if [[ -z "$SSH_PASSWORD" ]]; then
        SSH_OPTIONS+=(-o BatchMode=yes)
    else
        command -v sshpass >/dev/null || { echo 'Install sshpass for password authentication.' >&2; return 69; }
        SSH_OPTIONS+=(-o NumberOfPasswordPrompts=1)
    fi
}

runtime_init() {
    local hosts_file="$ATOMATOR_ROOT/hosts.txt" retry='' parsed item answer
    local selected=()
    ATOMATOR_DRY_RUN=0; ATOMATOR_YES=0
    MAX_PARALLEL=${MAX_PARALLEL:-5}
    while (($#)); do
        case "$1" in
            --host|--hosts-file|--retry-failed|--parallel)
                [[ $# -ge 2 && -n "$2" ]] || { echo "Missing value for $1" >&2; exit 64; }
                case "$1" in
                    --host) selected+=("$2");;
                    --hosts-file) hosts_file=$2;;
                    --retry-failed) retry=$2;;
                    --parallel) MAX_PARALLEL=$2;;
                esac
                shift 2;;
            --dry-run) ATOMATOR_DRY_RUN=1; shift;;
            --yes) ATOMATOR_YES=1; shift;;
            *) echo "Unknown option: $1" >&2; exit 64;;
        esac
    done
    [[ -f "$ATOMATOR_ROOT/.site-configured.json" ]] || { echo 'Run from a configured bundle.' >&2; exit 64; }
    [[ "$MAX_PARALLEL" =~ ^[1-9][0-9]{0,2}$ ]] && ((MAX_PARALLEL <= 128)) || { echo '--parallel must be 1 through 128.' >&2; exit 64; }
    ATOMATOR_TIMEOUT=${ATOMATOR_TIMEOUT:-1800}
    [[ "$ATOMATOR_TIMEOUT" =~ ^[1-9][0-9]{0,5}$ ]] || { echo 'ATOMATOR_TIMEOUT must be positive seconds.' >&2; exit 64; }
    parsed=$(python3 "$ATOMATOR_ROOT/lib/settings.py" hosts "$hosts_file") || exit 64
    mapfile -t ATOMATOR_HOSTS <<< "$parsed"
    if [[ -n "$retry" ]]; then
        ((${#selected[@]} == 0)) || { echo 'Use either --host or --retry-failed.' >&2; exit 64; }
        parsed=$(python3 "$ATOMATOR_ROOT/lib/settings.py" hosts "$retry") || exit 64
        mapfile -t selected <<< "$parsed"
    fi
    if ((${#selected[@]})); then
        local unique=() known found
        for item in "${selected[@]}"; do
            found=0
            for known in "${ATOMATOR_HOSTS[@]}"; do [[ "$known" == "$item" ]] && found=1; done
            ((found)) || { echo "Host is outside inventory: $item" >&2; exit 64; }
            found=0
            for known in "${unique[@]}"; do [[ "$known" == "$item" ]] && found=1; done
            ((found)) || unique+=("$item")
        done
        ATOMATOR_HOSTS=("${unique[@]}")
    fi
    printf 'Action: %s\nHosts (%s):\n' "$(basename -- "$0")" "${#ATOMATOR_HOSTS[@]}"
    printf '  %s\n' "${ATOMATOR_HOSTS[@]}"
    echo "Parallel limit: $MAX_PARALLEL | Command timeout: ${ATOMATOR_TIMEOUT}s"
    if ((ATOMATOR_DRY_RUN)); then echo 'Preview only. No connections made.'; exit 0; fi
    runtime_credentials || exit $?
    if ((!ATOMATOR_YES)); then
        read -r -p 'Run on these hosts? (yes/no): ' answer || exit 0
        [[ "$answer" == yes ]] || exit 0
    fi
    # Keep installation switches out of active jobs, including their log writes.
    local lock_file="${ATOMATOR_ROOT%/*}/.$(basename "$ATOMATOR_ROOT").runtime-lock"
    [[ ! -L "$lock_file" ]] || { echo 'Runtime lock must not be a symlink.' >&2; exit 64; }
    exec {ATOMATOR_LOCK_FD}> "$lock_file" || exit 1
    flock -sn "$ATOMATOR_LOCK_FD" || { echo 'An installation is active. Retry after it finishes.' >&2; exit 75; }
    mkdir -p -- "$ATOMATOR_ROOT/reports" || exit 1
    ATOMATOR_RUN_DIR=$(mktemp -d "$ATOMATOR_ROOT/reports/$(date -u +%Y%m%dT%H%M%SZ)-$(basename "$0" .sh)-XXXXXX") || exit 1
    mkdir -- "$ATOMATOR_RUN_DIR/status" "$ATOMATOR_RUN_DIR/errors" || exit 1
    printf '%s\n' "${ATOMATOR_HOSTS[@]}" > "$ATOMATOR_RUN_DIR/hosts.txt"
    ATOMATOR_OWNER=$BASHPID
    trap 'runtime_finish $?' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
}

runtime_record() {
    local host=$1 rc=$2 key=${1//:/_}
    if ((rc)); then
        printf '%s\n' "$rc" > "$ATOMATOR_RUN_DIR/status/$key.failed"
    else
        : > "$ATOMATOR_RUN_DIR/status/$key.ok"
    fi
}

runtime_finish() {
    local rc=$1 host key status code ok=0 failed=0 cancelled=0 attempted=0
    [[ "$BASHPID" == "$ATOMATOR_OWNER" ]] || return "$rc"
    trap - EXIT
    if ((rc == 130 || rc == 143)); then
        for pid in "${ATOMATOR_PIDS[@]}"; do kill "$pid" 2>/dev/null || :; done
        for pid in "${ATOMATOR_PIDS[@]}"; do wait "$pid" 2>/dev/null || :; done
    fi
    printf 'host\tstatus\texit_code\n' > "$ATOMATOR_RUN_DIR/results.tsv"
    : > "$ATOMATOR_RUN_DIR/failed-hosts.txt"
    for host in "${ATOMATOR_HOSTS[@]}"; do
        key=${host//:/_}
        [[ -f "$ATOMATOR_RUN_DIR/status/$key.failed" || -f "$ATOMATOR_RUN_DIR/status/$key.ok" ]] && attempted=1
    done
    for host in "${ATOMATOR_HOSTS[@]}"; do
        key=${host//:/_}; code=0
        if [[ -f "$ATOMATOR_RUN_DIR/status/$key.failed" ]]; then
            status=FAILED; code=$(cat "$ATOMATOR_RUN_DIR/status/$key.failed")
        elif [[ -f "$ATOMATOR_RUN_DIR/status/$key.ok" ]]; then
            status=OK
        elif ((attempted == 0 && rc == 0)); then
            status=CANCELLED
        else
            status=NOT_COMPLETED; code=125
        fi
        if [[ "$status" == OK ]]; then
            ok=$((ok+1))
        elif [[ "$status" == CANCELLED ]]; then
            cancelled=$((cancelled+1))
        else
            failed=$((failed+1)); printf '%s\n' "$host" >> "$ATOMATOR_RUN_DIR/failed-hosts.txt"
            printf '[%s] %s (exit %s)\n' "$host" "$status" "$code" >&2
        fi
        printf '%s\t%s\t%s\n' "$host" "$status" "$code" >> "$ATOMATOR_RUN_DIR/results.tsv"
    done
    printf 'Results: %s OK, %s failed or incomplete, %s cancelled\nSaved: %s\n' "$ok" "$failed" "$cancelled" "$ATOMATOR_RUN_DIR" >&2
    ((rc == 0 && failed > 0)) && rc=1
    exit "$rc"
}

_transport() {
    local kind=$1 host=$2; shift 2
    local command=(ssh -p "$SSH_PORT" "${SSH_OPTIONS[@]}" -- "$SSH_USER@$host" "$@")
    if [[ "$kind" == scp ]]; then
        local destination=$2
        [[ "$host" == *:* ]] && host="[$host]"
        command=(scp -P "$SSH_PORT" "${SSH_OPTIONS[@]}" -- "$1" "$SSH_USER@$host:$destination")
    fi
    if [[ -n "$SSH_PASSWORD" ]]; then
        SSHPASS="$SSH_PASSWORD" timeout --foreground "$ATOMATOR_TIMEOUT" sshpass -e "${command[@]}"
    else
        timeout --foreground "$ATOMATOR_TIMEOUT" "${command[@]}"
    fi
}

remote_input() {
    local host=$1 key=${1//:/_} rc=0; shift
    local out err
    out=$(mktemp "$ATOMATOR_RUN_DIR/output.XXXXXX") || return 1
    err=$(mktemp "$ATOMATOR_RUN_DIR/error.XXXXXX") || return 1
    _transport ssh "$host" "$@" > "$out" 2> "$err" || rc=$?
    cat -- "$out"
    cat -- "$err" >&2
    cat -- "$err" >> "$ATOMATOR_RUN_DIR/errors/$key.log"
    rm -f -- "$out" "$err"
    runtime_record "$host" "$rc"
    return "$rc"
}

remote_exec() { remote_input "$@" < /dev/null; }

remote_copy() {
    local host=$1 rc=0 key=${1//:/_}; shift
    _transport scp "$host" "$@" 2> "$ATOMATOR_RUN_DIR/errors/$key.scp.log" || rc=$?
    cat "$ATOMATOR_RUN_DIR/errors/$key.scp.log" >&2
    runtime_record "$host" "$rc"
    return "$rc"
}

remote_script() {
    local host=$1 payload=$2; shift 2
    local command='sudo -n bash -se --' arg
    [[ "$SSH_USER" == root ]] && command='bash -se --'
    for arg in "$@"; do
        command+=" $(shell_quote "$arg")"
    done
    remote_input "$host" "$command" < "$payload"
}

shell_quote() { local value=${1//\'/\'\\\'\'}; printf "'%s'" "$value"; }

fleet_run() {
    local callback=$1 host pid rc
    local pids=()
    ATOMATOR_PIDS=()
    for host in "${ATOMATOR_HOSTS[@]}"; do
        (
            trap 'runtime_record "$host" "$?"' EXIT
            trap 'exit 130' INT
            trap 'exit 143' TERM
            set -e
            "$callback" "$host"
        ) > "$ATOMATOR_RUN_DIR/${host//:/_}.log" 2>&1 &
        pids+=("$!")
        ATOMATOR_PIDS+=("$!")
        if ((${#pids[@]} >= MAX_PARALLEL)); then
            for pid in "${pids[@]}"; do wait "$pid" || :; done
            pids=()
            ATOMATOR_PIDS=()
        fi
    done
    for pid in "${pids[@]}"; do wait "$pid" || :; done
    ATOMATOR_PIDS=()
    for host in "${ATOMATOR_HOSTS[@]}"; do
        printf '\n[%s]\n' "$host"
        cat -- "$ATOMATOR_RUN_DIR/${host//:/_}.log"
    done
}

runtime_watchdog_config() {
    local parsed values=()
    parsed=$(mktemp) || return 1
    python3 "$ATOMATOR_ROOT/lib/settings.py" watchdog "$ATOMATOR_ROOT/watchdog_hosts.conf" > "$parsed" || { rm -f "$parsed"; return 64; }
    mapfile -d '' -t values < "$parsed"; rm -f "$parsed"
    HOST_1=${values[0]}; HOST_2=${values[1]}; HOST_3=${values[2]}
    [[ "${1:-}" == --allow-empty || ( -n "$HOST_1" && -n "$HOST_2" ) ]] || { echo 'Configure at least HOST_1 and HOST_2 first.' >&2; return 64; }
}
