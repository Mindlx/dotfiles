当前配置说明（2026-06-29）

一、硬件架构

双 RTX 3090 24GB + AMD Ryzen 9 5950X + 64GB 内存

GPU0 (Cuda:0) → lla-qw35-gpu0 容器 → port 11434
GPU1 (Cuda:1) → lla-orn-gpu1 容器 → port 15433

二、模型配置

GPU0: Qwen3.6-35B-A3B-UD-IQ4_XS (MoE, ~3.5B 活跃参数)
  - 端口: 11434
  - 量化: IQ4_XS (约 18GB)
  - 架构: MoE, 262K 上下文
  - MTP: 开启 (draft-mtp, n-max 2)
  - 速度: ~145 t/s
  - 定位: 日常对话、轻量编码、通用任务

GPU1: Ornith-1.0-35B IQ4_XS (MoE, ~3B 活跃参数)
  - 端口: 15433
  - 量化: IQ4_XS (约 18GB)
  - 架构: MoE, 基于 Qwen3.5, 262K 上下文
  - MTP: 无（原生不支持，用 ngram 推测解码替代）
  - ngram-mod: n_match=24, n_max=64, n_min=48（无质量影响）
  - 速度: ~130 t/s
  - 定位: Agent 编码、代码审查、复杂推理

云端: DeepSeek
  - v4-flash: 日常 agent 任务（explore/librarian/quick 等）
  - v4-pro: 高难度推理（oracle/ultrabrain/deep）

三、Agent 路由 (oh-my-openagent.json)

GPU0 (Qwen3.6-35B) 负责:
  - explore: 代码搜索探索
  - quick: 简单修改
  - unspecified-low: 轻度任务
  - writing: 文档写作

GPU1 (Ornith-1.0-35B) 负责:
  - hephaestus: 编码主力
  - sisyphus-junior: 子任务执行
  - visual-engineering: 前端/UI 任务
  - artistry: 创意类复杂问题

DeepSeek v4-flash 负责:
  - librarian: 外部文档搜索
  - multimodal-looker: 图片分析
  - prometheus/metis/momus/atlas: 规划、评估、审查
  - unspecified-high: 高复杂度任务

DeepSeek v4-pro 负责:
  - oracle: 架构设计、高难度调试
  - ultrabrain: 复杂逻辑
  - deep: 自主问题求解

四、部署文件位置

配置文件:
  docker-compose.yaml                       -> /opt/ai-workspace/docker-compose.yaml
  OpenCode 全局配置                           -> ~/.config/opencode/opencode.json
  Agent 路由配置                             -> ~/.config/opencode/oh-my-openagent.json
  ACP 压缩配置                               -> ~/.config/opencode/acp.jsonc

模型文件:
  Qwen3.6-35B-A3B-UD-IQ4_XS.gguf           -> /opt/ai-workspace/models/
  deepreinforce-ai_Ornith-1.0-35B-IQ4_XS.gguf -> /opt/ai-workspace/models/
  Qwen3.6-27B-UD-Q4_K_XL.gguf (备用)         -> /opt/ai-workspace/models/
  mmproj-Qwen3.6-27B-f16.gguf (备用)         -> /opt/ai-workspace/models/

备份文件:
  docker-compose.yaml.bak.27b-35b-optimized  -> /opt/ai-workspace/ （含所有优化参数）

五、常用操作

查看容器状态:
  docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

查看 GPU 状态:
  nvidia-smi

查看生成速度:
  curl -s http://localhost:11434/v1/chat/completions -d '{...}'

重启某个容器:
  docker compose -f /opt/ai-workspace/docker-compose.yaml up -d lla-qw35-gpu0
  docker compose -f /opt/ai-workspace/docker-compose.yaml up -d lla-orn-gpu1

重启所有:
  docker compose -f /opt/ai-workspace/docker-compose.yaml up -d

六、恢复到 27B + 35B 组合

如果以后想回到原来的 Qwen3.6-27B(GPU0) + Qwen3.6-35B(GPU1) 配置:

  第一步: 停止当前容器
  docker compose -f /opt/ai-workspace/docker-compose.yaml down

  第二步: 用备份文件覆盖
  cp docker-compose.yaml.bak.27b-35b-optimized docker-compose.yaml

  第三步: 恢复 OpenCode 的 agent 路由配置
  编辑 ~/.config/opencode/oh-my-openagent.json 将所有 gpu0-local/qwen3.6-35b 改回 gpu0-local/qwen3.6-27b，将所有 gpu1-local/ornith-35b 改回 gpu1-local/qwen3.6-35b

  第四步: 恢复 provider 配置
  编辑 ~/.config/opencode/opencode.json 将 GPU0 的模型改回 Qwen3.6-27B-UD-Q4_K_XL.gguf，GPU1 改回 Qwen3.6-35B-A3B-UD-IQ4_XS.gguf

  第五步: 启动容器
  docker compose -f /opt/ai-workspace/docker-compose.yaml up -d

  第六步: 重启 OpenCode

七、容器关键参数说明

GPU0 (Qwen3.6-35B):
  - cache-type-k q8_0 / cache-type-v q4_0: 不对称 KV cache，质量与显存的最佳平衡
  - flash-attn on: Flash Attention 加速
  - ngl 99: 全层 GPU 推理
  - b 2048 -ub 1024: 批次优化，MTP 场景专用
  - mlock: 锁定内存防止 swap
  - no-mmap: 防止页错误导致的速度波动
  - spec-type draft-mtp: MTP 推测解码
  - spec-draft-n-max 2: 每次推测 2 个 token
  - spec-draft-type-k/v q4_0: draft 模型 KV cache 降精度

GPU1 (Ornith-1.0-35B):
  - 同上基础参数，无 MTP 相关参数
  - jinja: 启用 Jinja2 聊天模板
