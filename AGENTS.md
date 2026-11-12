# KCL CREATE HPC 控制项目

- 本项目只管理 CREATE 上的远程科研项目，不存放科研代码。
- 禁止在 login node 运行训练、CUDA、simulation 或重计算；正式计算必须通过 Slurm。
- 默认 GPU partition 为 `gpu`，默认申请 1–2 张 A100；超过 2 张必须得到用户明确确认。
- 大文件、dataset、checkpoint、cache 不得放 `$HOME`，优先使用 scratch 或 project storage。
- 不得保存 SSH private key、密码、token 或 API key。
- 不得创建无限自动重试或无限轮询。
- 提交任务必须先展示完整资源计划并得到用户明确确认。
- 不得未经确认取消正常运行中的 job；所有取消操作均须显式确认。
