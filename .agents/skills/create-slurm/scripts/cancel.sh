#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 1 ]] || fail 'Usage: cancel.sh JOB_ID'
job_id "$1"
record=$(squeue -h -u "$USER" -j "$1" --format='%i|%j|%T')
[[ -n $record ]] || fail 'No owned active job found; nothing cancelled'
printf 'Job ID | Name | Current state\n%s\n' "$record"
printf 'Type CANCEL %s to confirm cancellation: ' "$1" >&2
IFS= read -r answer || fail 'Confirmation required'
[[ $answer == "CANCEL $1" ]] || fail 'Cancellation not confirmed'
scancel --user="$USER" "$1"
