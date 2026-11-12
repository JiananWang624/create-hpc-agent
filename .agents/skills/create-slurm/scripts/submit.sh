#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
usage() {
    echo 'Usage: submit.sh [--dry-run] --project /path --checkpoint /path [--partition NAME] [--gpu-type TYPE] [--gpus N] [--cpus N] [--memory 64G] [--time 24:00:00] [--logs /path] [--data /path] [--cache /path] [--override-gpu-limit] -- COMMAND ARG...'
}
dry=false; override=false; project=; checkpoint=; data=; cache=
partition=${CFG[default_partition]}; gpu_type=${CFG[default_gpu_type]}; gpus=${CFG[default_gpu_count]}
cpus=${CFG[default_cpus]}; memory=${CFG[default_memory]}; walltime=${CFG[default_walltime]}
logs=$(expand_user "${CFG[log_root]}")
while (($#)); do
    case $1 in
        --dry-run) dry=true; shift;;
        --override-gpu-limit) override=true; shift;;
        --help|-h) usage; exit 0;;
        --) shift; break;;
        --project|--checkpoint|--partition|--gpu-type|--gpus|--cpus|--memory|--time|--logs|--data|--cache)
            (($# >= 2)) || fail "Missing value for $1"
            case $1 in
                --project) project=$2;; --checkpoint) checkpoint=$2;; --partition) partition=$2;;
                --gpu-type) gpu_type=$2;; --gpus) gpus=$2;; --cpus) cpus=$2;; --memory) memory=$2;;
                --time) walltime=$2;; --logs) logs=$2;; --data) data=$2;; --cache) cache=$2;;
            esac; shift 2;;
        *) usage >&2; fail "Unknown option: $1";;
    esac
done
(($#)) || fail 'A command after -- is required'
positive GPUs "$gpus"; positive CPUs "$cpus"; positive GPU-limit "${CFG[max_gpu_without_confirmation]}"
if ((gpus > CFG[max_gpu_without_confirmation])) && ! $override; then
    fail 'GPU count exceeds configured limit; explicit user approval and --override-gpu-limit required'
fi
allowed=false
for item in "${PARTITIONS[@]}"; do [[ $partition != "$item" ]] || allowed=true; done
$allowed || fail "Unknown or disallowed partition: $partition"
[[ $gpu_type =~ ^[a-zA-Z0-9_-]+$ ]] || fail 'Invalid GPU type'
[[ $memory =~ ^[1-9][0-9]*[MG]$ ]] || fail 'Memory must be a positive integer followed by M or G'
duration=$(seconds "$walltime"); limit=$(seconds "${CFG[max_default_walltime]}")
((duration > 0 && duration <= limit)) || fail 'Walltime exceeds policy; verify long partition/special permission and explicitly revise config before proceeding'
[[ $project == /* && -d $project ]] || fail 'Remote project must be an existing absolute directory on this host'
project=$(realpath -- "$project")
[[ $project != *$'\n'* && $project != *$'\r'* && $project != *'"'* && $project != *'%'* ]] || fail 'Unsupported characters in project path'
storage_path checkpoint "$checkpoint"; storage_path logs "$logs"
[[ -n $data ]] || data=$(expand_user "${CFG[scratch_root]}")/datasets
[[ -n $cache ]] || cache=$(expand_user "${CFG[scratch_root]}")/cache
storage_path data "$data"; storage_path cache "$cache"
logs=$(realpath -m -- "$logs"); checkpoint=$(realpath -m -- "$checkpoint"); cache=$(realpath -m -- "$cache")
[[ $logs != *'"'* ]] || fail 'Double quotes are unsupported in log path'
# Dry-run checks the nearest existing ancestor without creating directories.
for dir in "$logs" "$checkpoint" "$cache"; do
    ancestor=$dir
    while [[ ! -e $ancestor ]]; do ancestor=$(dirname -- "$ancestor"); done
    [[ -d $ancestor && -w $ancestor && -x $ancestor ]] || fail "Directory cannot be created/accessed: $dir"
    [[ ! -e $dir || -d $dir ]] || fail "Not a directory: $dir"
done
printf -v command '%q ' "$@"
script=$(cat <<EOF
#!/usr/bin/env bash
#SBATCH --partition=$partition
#SBATCH --gres=gpu:$gpu_type:$gpus
#SBATCH --cpus-per-task=$cpus
#SBATCH --mem=$memory
#SBATCH --time=$walltime
#SBATCH --chdir="$project"
#SBATCH --output="$logs/%j.out"
#SBATCH --error="$logs/%j.err"
set -euo pipefail
EOF
)
printf -v exports 'export CHECKPOINT_DIR=%q\nexport XDG_CACHE_HOME=%q\nexport HF_HOME=%q\nexport TORCH_HOME=%q' "$checkpoint" "$cache" "$cache/huggingface" "$cache/torch"
script+=$'\n'"$exports"$'\n'"exec $command"
bash -n <<< "$script" || fail 'Generated batch script has invalid Bash syntax'
printf 'remote project: %s\npartition: %s\nGPU type: %s\nGPU count: %s\nCPU: %s\nmemory: %s\nwalltime: %s\nworking directory: %s\nlog path: %s/%%j.{out,err}\ncheckpoint path: %s\ndata path: %s\ncache path: %s\ncommand: %s\n' "$project" "$partition" "$gpu_type" "$gpus" "$cpus" "$memory" "$walltime" "$project" "$logs" "$checkpoint" "$data" "$cache" "$command"
printf '\nFinal sbatch plan (sbatch --parsable --export=NONE < generated-script):\n%s\n' "$script"
if $dry; then
    printf '\nDRY-RUN: no directories created; no Slurm commands executed. Cluster acceptance remains unverified.\n'
    exit 0
fi
printf '\nType SUBMIT to confirm this exact plan: ' >&2
IFS= read -r answer || fail 'Confirmation required'
[[ $answer == SUBMIT ]] || fail 'Submission not confirmed'
command -v sbatch >/dev/null || fail 'sbatch unavailable; run on CREATE login node'
mkdir -p -- "$logs" "$checkpoint" "$cache"
# SBATCH_* environment options override file directives and could change the plan.
for variable in "${!SBATCH_@}"; do unset "$variable"; done
# Slurm validates site-specific options without scheduling before actual submission.
sbatch --test-only --export=NONE <<< "$script"
result=$(sbatch --parsable --export=NONE <<< "$script")
printf 'Job ID: %s\n' "$result"
