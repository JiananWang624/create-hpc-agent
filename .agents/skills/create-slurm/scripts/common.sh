#!/usr/bin/env bash
# Shared configuration and validation; never source configuration as shell code.
set -euo pipefail
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../.." && pwd)
declare -A CFG=()
PARTITIONS=()
list=false
while IFS= read -r line || [[ -n $line ]]; do
    line=${line%$'\r'}
    [[ $line =~ ^[[:space:]]*(#.*)?$ ]] && continue
    if [[ $line =~ ^[[:space:]]+-[[:space:]]+([a-zA-Z0-9_-]+)$ ]] && $list; then
        PARTITIONS+=("${BASH_REMATCH[1]}")
    elif [[ $line =~ ^([a-z_]+):[[:space:]]*(.*)$ ]]; then
        key=${BASH_REMATCH[1]}; value=${BASH_REMATCH[2]}; list=false
        if [[ $key == allowed_partitions && -z $value ]]; then list=true; continue; fi
        if [[ $value == \"*\" ]]; then value=${value:1:${#value}-2}; fi
        [[ -n $value ]] || fail "Missing config value: $key"
        CFG[$key]=$value
    else
        fail "Unsupported config syntax: $line (use simple scalars and allowed_partitions list)"
    fi
done < "$ROOT/config/create.yaml"
for key in ssh_alias default_partition default_gpu_type default_gpu_count max_gpu_without_confirmation max_default_walltime default_walltime default_cpus default_memory scratch_root log_root require_confirmation_before_submit require_confirmation_before_cancel; do
    [[ -n ${CFG[$key]:-} ]] || fail "Missing config key: $key"
done
[[ ${#PARTITIONS[@]} -gt 0 ]] || fail 'allowed_partitions is empty'
# These controls cannot be disabled accidentally through configuration.
[[ ${CFG[require_confirmation_before_submit]} == true && ${CFG[require_confirmation_before_cancel]} == true ]] || fail 'Confirmation must remain enabled'
[[ ${USER:-} =~ ^[a-zA-Z0-9_.-]+$ ]] || fail 'USER is missing or invalid'
expand_user() { local value=$1; value=${value//\$\{USER\}/$USER}; printf '%s\n' "${value//\$USER/$USER}"; }
positive() { [[ $2 =~ ^[1-9][0-9]{0,5}$ ]] || fail "$1 must be a positive integer"; }
job_id() { [[ ${1:-} =~ ^[1-9][0-9]*(_[0-9]+)?$ ]] || fail 'Expected numeric Job ID (or array task ID)'; }
seconds() {
    [[ $1 =~ ^([0-9]{1,4}):([0-5][0-9]):([0-5][0-9])$ ]] || fail 'Walltime must be HHHH:MM:SS'
    printf '%s\n' "$((10#${BASH_REMATCH[1]} * 3600 + 10#${BASH_REMATCH[2]} * 60 + 10#${BASH_REMATCH[3]}))"
}
storage_path() {
    local path home
    [[ $2 == /* && $2 != *$'\n'* && $2 != *$'\r'* && $2 != *'$'* && $2 != *'%'* ]] || fail "$1 must be an absolute, expanded path without Slurm % tokens"
    path=$(realpath -m -- "$2"); home=$(realpath -m -- "$HOME")
    [[ $path != "$home" && $path != "$home/"* ]] || fail "$1 cannot be inside HOME: $path"
}
