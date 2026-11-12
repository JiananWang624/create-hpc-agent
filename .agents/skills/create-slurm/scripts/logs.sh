#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# -ge 1 && $# -le 2 ]] || fail 'Usage: logs.sh JOB_ID [absolute-training-log-path]'
job_id "$1"; id=$1
paths=("$(expand_user "${CFG[log_root]}")/$id.out" "$(expand_user "${CFG[log_root]}")/$id.err")
# Slurm metadata may expire; accounting and configured paths remain useful.
info=$(scontrol show job "$id" -o 2>/dev/null || true)
for field in StdOut StdErr; do
    if [[ $info =~ $field=([^[:space:]]+) ]]; then
        path=${BASH_REMATCH[1]}
        path=${path//%j/$id}
        paths+=("$path")
    fi
done
workdir=$(sacct -n -X -u "$USER" -j "$id" --format=WorkDir --parsable2 2>/dev/null | head -n 1 || true)
workdir=${workdir%|}
if [[ $workdir == /* && -d $workdir ]]; then
    paths+=("$workdir/slurm-$id.out")
    for path in "$workdir/train.log" "$workdir/training.log" "$workdir/logs/train.log"; do
        [[ ! -f $path ]] || paths+=("$path")
    done
fi
if [[ $# == 2 ]]; then [[ $2 == /* ]] || fail 'Training log path must be absolute'; paths+=("$2"); fi
declare -A seen=()
found=false
for path in "${paths[@]}"; do
    [[ -z ${seen[$path]:-} ]] || continue
    seen[$path]=1
    if [[ -f $path && -r $path ]]; then
        found=true
        printf '\n--- %s (last 100 lines; shared training logs may contain other runs) ---\n' "$path"
        tail -n 100 -- "$path"
    fi
done
$found || fail 'Logs not found; job may be pending or metadata purged. Supply the exact training log path; inspect sacct/scontrol for custom output paths.'
