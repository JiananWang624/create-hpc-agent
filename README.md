# CREATE HPC 本地控制项目

用 Codex + SSH + Bash + Slurm 管理远程项目；这里不保存科研代码，也没有后台服务。Skill 位于 [.agents/skills/create-slurm](.agents/skills/create-slurm/SKILL.md)。

## 准备

1. 在本机 SSH 配置中自行设置别名 `create`；密钥交给 SSH 管理，不放本仓库。
2. 查看 [config/create.yaml](config/create.yaml)，连接后核实 scratch/project storage、partition、GPU 类型、账户权限和时间限制。不要写死用户名；`$USER` 在远端展开。
3. 本地可使用 Git Bash / WSL；远端要求 Bash 4+、GNU coreutils、Slurm。脚本通过 `bash 脚本路径` 调用，无需可执行位。配置支持简单 `key: value`、双引号字符串和 partition 列表，不支持任意 YAML 语法或 shell 求值。
4. 让 Codex 使用 `$create-slurm`，或直接提出下面的 CREATE 请求。首次操作将控制文件传至远程 scratch 的独立目录，保留目录结构。实际提交前必须重新展示计划并等待你确认。

## 常用请求

- “在 CREATE 上运行远程项目 /path/to/project，使用 2 张 A100 运行 train.py，最长 24 小时。先检查资源，生成 Slurm 计划给我确认，确认后再提交。”
- “检查我当前 CREATE 上所有 job。”
- “分析 Job 123456 为什么失败，先给证据与修改建议。”
- “查看 Job 123456 的训练日志。”
- “取消 Job 123456；先展示名称与当前状态给我确认。”

## 脚本用法（在远端控制目录）

```bash
bash .agents/skills/create-slurm/scripts/submit.sh --dry-run \
  --project /path/to/project --gpus 2 --time 24:00:00 \
  --checkpoint "/scratch/users/$USER/checkpoints/project" \
  --data "/scratch/users/$USER/datasets/example" \
  -- python train.py
bash .agents/skills/create-slurm/scripts/queue.sh
bash .agents/skills/create-slurm/scripts/status.sh 123456
bash .agents/skills/create-slurm/scripts/logs.sh 123456
bash .agents/skills/create-slurm/scripts/cancel.sh 123456
```

dry-run 只检查当前主机上的路径与策略、生成并打印 batch，不连接、不创建目录、不调用 Slurm。实际使用需在 CREATE 上运行，因此本地项目路径检查不能证明远程路径存在。去掉 `--dry-run` 后须输入 `SUBMIT`，随后先做 Slurm test-only 校验再提交一次；取消须输入 `CANCEL 123456`。不要在用户确认前向这些提示自动输入答案。

超过 2 GPU 默认拒绝；明确同意后可加 `--override-gpu-limit`。超过配置时间上限仍拒绝，需先核实 long partition/权限并批准修改配置。日志默认 `<log_root>/<jobid>.out/.err`，每次最多读取末尾 100 行；自定义训练日志可作为第二个参数提供。

checkpoint 环境变量为 `CHECKPOINT_DIR`，需训练代码主动使用；`--data` 只检查/展示路径，不自动改训练参数。启动脚本还需检查项目自己的数据、cache 和输出配置；本工具不能证明任意命令绝不会写入 HOME。环境通过 `--export=NONE` 隔离，module/conda 等初始化应写在远程项目已有启动脚本中；不要把 secret 写入命令或日志。

离线示例可将 `--project` 换成现有的本地 Bash 绝对路径，并为 `--logs`、`--checkpoint`、`--data`、`--cache` 使用 HOME 之外可写的临时路径；无需安装或连接 Slurm。正式计算始终走 Slurm。
