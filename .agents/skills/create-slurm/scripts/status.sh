#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
[[ $# == 1 ]] || fail 'Usage: status.sh JOB_ID'
job_id "$1"
printf 'Live queue (completed jobs may be absent):\n'
squeue -u "$USER" --jobs="$1" --format='%.20i %.24j %.16T %.12M %R' || printf 'No live queue record; checking accounting.\n' >&2
sacct -u "$USER" -j "$1" --parsable2 --format=JobID,JobName,State,Elapsed,Timelimit,ExitCode,Reason,MaxRSS,ReqTRES,AllocTRES
