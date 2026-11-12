#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
squeue -u "$USER" --format='%.20i %.24j %.12P %.12T %.12M %.6D %R'
