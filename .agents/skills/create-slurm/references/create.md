# KCL CREATE 本地约定与现场核实

- CREATE login node 只用于 SSH、编辑、传输和轻量 Slurm 查询/提交；训练、CUDA、simulation、重计算必须进入 Slurm allocation。
- 本项目默认 `gpu`，允许列表另含 `interruptible_gpu`。这些是用户指定的初始配置，尚未连接 CREATE 验证；使用前通过 `sinfo` 和当前 CREATE 官方文档核实名称、访问权限、GPU GRES 命名与时间上限。
- 默认请求 `gpu:a100:1`，通常为 1–2 张 A100；超过 2 张需明确确认与 override。型号、显存和节点拓扑以现场信息为准；两张 GPU 不保证训练代码会自动使用两张。
- interruptible 资源可能受站点抢占规则影响；采用前先核实并告知用户，需要项目支持 checkpoint/resume，不默认迁移到该 partition。
- `/scratch/users/$USER` 是可编辑路径模板，不是已经核实的 CREATE 存储承诺。先查账户实际 scratch/project storage、配额、保留与清理政策。大数据、checkpoint、cache 和训练日志放 scratch/project storage；scratch 不当作永久备份。
- 48 小时是本控制项目的默认安全上限，不代表 CREATE 所有 partition 的实际限制。`sinfo` 的 TIMELIMIT 和站点/账户 QOS 可能更严格；较长任务需核实适用 partition 或特殊权限，不自动使用名称含 long 的未知分区。
- 常见状态：PENDING 查 Reason（Resources/Priority/账户或 QOS 限制）；RUNNING 查有限日志；COMPLETED 仍核对退出码与预期产物；FAILED 查 traceback/step；OUT_OF_MEMORY 区分主机与 CUDA 内存；TIMEOUT 检查恢复点；CANCELLED 核实取消原因。节点故障或抢占也不自动重提。

本文件未记录任何已经在线核验的站点事实；将来核实政策时记录来源和日期，避免把本地默认值写成官方政策。
