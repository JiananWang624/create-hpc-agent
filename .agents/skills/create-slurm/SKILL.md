---
name: create-slurm
description: 通过 SSH 和 Slurm 管理 KCL CREATE 远程科研项目的资源、提交、队列、状态、日志、失败诊断和取消；适用于 CREATE 运维请求。
---

# CREATE / Slurm

先读项目根目录的 [AGENTS.md](../../../AGENTS.md)、[配置](../../../config/create.yaml) 和 [CREATE 说明](references/create.md)。本地控制项目不存放科研代码或密钥。

## 连接与只读操作

使用配置中的 `ssh_alias` 和用户已有 SSH 配置；不猜测用户名、不读取或复制私钥。脚本需要在 CREATE 的 Bash 4+、GNU coreutils 和 Slurm 环境中运行，本地调用 SSH 只负责传输与执行。不要在本地把 `$USER` 展开为 Windows 用户名。

首次使用时可将本控制项目的配置和脚本上传至远程 scratch 下独立控制目录，保留相对目录结构；只传控制文件，不同步科研目录，不覆盖远程现有修改。先在远程查询实际 scratch 路径并确认其存在，不假定配置中的示例路径适用于该账户。

- 资源：通过 SSH 执行 `sinfo -o '%P %a %l %D %G'`，必要时 `sinfo -N -p gpu -o '%N %t %G'`；再查看 `squeue -u "$USER"`。查询失败则停止提交流程，不据此猜测资源可用。
- 我的任务：运行 `scripts/queue.sh`。
- 指定任务：运行 `scripts/status.sh JOB_ID`，同时读实时队列和 accounting；已完成任务不在 squeue 中是正常现象。
- 日志：运行 `scripts/logs.sh JOB_ID [绝对训练日志路径]`。只读最近 100 行，不使用无限 follow/轮询。默认 `%j.out` / `%j.err` 自动定位；历史自定义路径、含空格的 Slurm 元数据路径或 array 输出定位失败时，查询原始 `scontrol` / `sacct` 并指定准确路径，不递归搜索整个存储。

## 提交流程（固定顺序）

用户请求 → 检查当前资源 → 解析远程项目路径 → 生成 Slurm 配置 → dry-run → 展示最终资源计划 → 等待用户明确确认 → 提交 → 返回 Job ID。

1. 用远程 `realpath` / `test -d` 解析项目路径，检查入口、环境、dataset、checkpoint、cache 和日志路径。路径或算法相关参数不明确且影响结果时询问用户。不要执行训练来检查入口。
2. 按用户需求选择资源，默认值读取配置。`gpu` / `a100` 是请求值；以现场 `sinfo`、账户权限和站点文档核实，不把空闲 GPU 当作可调度承诺。
3. 使用 `scripts/submit.sh --dry-run --project ... --checkpoint ... [资源参数] -- COMMAND ARG...`。脚本生成单一 Slurm 文件并检查 Bash 语法和本地策略；不接受未经检查的外部 batch 文件。命令参数按 shell 参数传递，不拼接不可信字符串。需要 module/conda 时使用远程项目已有的、已检查的启动脚本；其中不得隐藏额外 `#SBATCH` 配置或提交其他任务。
4. 完整展示以下字段以及生成的 batch 内容：

   ```text
   remote project:
   partition:
   GPU type:
   GPU count:
   CPU:
   memory:
   walltime:
   working directory:
   log path:
   checkpoint path:
   command:
   ```

   同时展示 data/cache 路径。确认的是这一次具体计划；任何资源、命令或路径变化都需重新 dry-run 和确认。未经用户对最终计划明确确认，不得调用任何 `sbatch`（包括 `--test-only`）。
5. 用户确认后，以相同参数去掉 `--dry-run`，在脚本提示时输入 `SUBMIT`。超过配置 GPU 上限还需用户明确同意该数量并加 `--override-gpu-limit`；这个参数不替代提交确认。脚本先执行 `sbatch --test-only`，通过后才提交一次。任何失败都停止，无自动重提；若提交返回不明确，先查队列/accounting，避免重复提交。
6. 返回 Job ID、资源、日志及 checkpoint 路径。只做一次初始状态查询；持续监控须用户明确请求并约定次数/时限。

命令由项目负责将 checkpoint 写入 `CHECKPOINT_DIR`；该环境变量不是对任意训练代码的强制重定向。`--data` 是被检查并展示的路径，仍须传给项目自己的参数。脚本设置 XDG/Hugging Face/Torch cache 变量；检查项目是否另有 cache 或 dataset 配置，不宣称可以静态识别任意命令中的 `$HOME` 写入。

## 失败和取消

分析时结合 `sacct` 的 job/step State、ExitCode、Elapsed、Timelimit、MaxRSS、ReqTRES/AllocTRES 与 stderr/stdout/训练日志，区分事实与推测：

- `FAILED` / 非零退出：查最早 traceback、环境/路径/依赖问题；ExitCode 为退出码:信号。
- CUDA OOM：找明确 CUDA OOM 证据；提出减小 batch、梯度累积等建议，未经同意不改变科研协议或直接加 GPU。
- `OUT_OF_MEMORY`：通常是主机内存限制，区别于 CUDA OOM；MaxRSS 可能只在 step 中出现。
- `TIMEOUT`：对比运行时长/限制，检查 checkpoint 与恢复支持。超配置上限应先核实 long partition/权限，再由用户批准调整配置；不猜 CREATE 的实际最长时间。
- `CANCELLED`：核对 Reason、取消者（如 accounting 提供）和时间；不要自动断言是用户、抢占或系统错误。

先给证据和修改建议，修复后重新走完整提交流程，不自动重试。

取消一律运行 `scripts/cancel.sh JOB_ID`。先展示 Job ID、名称、当前状态并等待用户明确确认，再输入 `CANCEL JOB_ID`。既往提交许可不授权取消；即使 job 正在运行也不可跳过确认。
