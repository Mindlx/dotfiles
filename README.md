# dotfiles — OpenCode AI Environment

OpenCode 全局配置 + Docker AI 推理环境部署模板，新机器一键引导。

## 仓库结构

```
dotfiles/
├── config/opencode/              ← OpenCode 配置（跨机器复用）
│   ├── opencode.json              — providers, MCP, plugins
│   ├── oh-my-openagent.json       — agent→model 映射
│   ├── acp.jsonc                  — ACP 协议配置
│   ├── supermemory.jsonc          — 持久化记忆
│   ├── AGENTS.md                  — codebase-memory-mcp 指令
│   ├── package.json               — 插件依赖清单
│   ├── plugin/                    — 插件初始化脚本
│   └── skill/                     — 自定义 skills（7 个 GitNexus skills）
├── machine/                       ← 机器部署模板（需按机定制）
│   ├── docker-compose.template.yaml
│   ├── deploy/                    — 辅助部署脚本
│   └── README.md
├── install.sh                     ← 新机器引导安装
└── README.md                      ← 本文件
```

---

## 一、新机器快速安装

### 前置条件

- **操作系统**: Linux x86_64
- **NVIDIA GPU** + CUDA driver 已安装
- **Docker** + nvidia-container-toolkit 已配置
- Node.js >= 18
- Git

### 步骤

```bash
# 1. 克隆
git clone git@github.com:Mindlx/dotfiles.git ~/.dotfiles

# 2. 一键安装 opencode 配置
cd ~/.dotfiles && bash install.sh

# 3. 设置环境变量（写入 ~/.bashrc 或 ~/.zshrc）
export DEEPSEEK_API_KEY="sk-your-deepseek-api-key"

# 4. 启动 OpenCode
#    重启终端后，opencode 会自动加载所有 MCP 和插件
```

### install.sh 做了什么

| 步骤 | 操作 |
|------|------|
| 1 | 把 `config/opencode/*` 软链到 `~/.config/opencode/` |
| 2 | 在 `~/.config/opencode/` 执行 `npm install` 安装插件依赖 |
| 3 | 安装 codebase-memory-mcp 二进制到 `~/.local/bin/` |

---

## 二、OpenCode 配置详解

### Providers（模型提供方）

`opencode.json` 配置了三个 provider：

| Provider | 模型 | 用途 | 地址 |
|----------|------|------|------|
| `gpu0-local` | Qwen3.6-27B (Q4_K_XL) | 日常 agent 任务 | `localhost:11434` |
| `gpu1-local` | Qwen3.6-35B (IQ4_XS) | librarian/explore/编码 | `localhost:15433` |
| `deepseek` | deepseek-v4-flash/pro | 复杂推理 / Oracle | `api.deepseek.com` |

> **注意**: 本地 provider 依赖 docker-compose 启动的 llama.cpp 服务。参见第三节。

### Agent → Model 映射

`oh-my-openagent.json` 配置了各 agent 的路由策略：

| Agent/Category | 模型 | 原因 |
|-------|-------|------|
| `oracle` | deepseek-v4-pro | 高难度架构/调试，需最强模型 |
| `ultrabrain` | deepseek-v4-pro | 复杂逻辑推理 |
| `deep` | deepseek-v4-pro | 自主问题求解 |
| `librarian` | gpu1 (35B) | 代码搜索，本地运行 |
| `explore` | gpu1 (35B) | 代码探索，本地运行 |
| `sisyphus-junior` | gpu1 (35B) | 执行子任务 |
| `visual-engineering` | gpu1 (35B) | 前端/UI 任务 |
| `quick` | gpu0 (27B) | 简单修改 |
| **`sisyphus`（你）** | **deepseek-v4-flash** | 编排、决策 |

### MCP 服务

| MCP 服务 | 来源 | 功能 |
|----------|------|------|
| **codebase-memory-mcp** | 手动配置 | 代码知识图谱（~/.local/bin/ 单二进制） |
| **gitnexus** | ❌ 已禁用 | 保留 CLI 可用，MCP 通道关闭 |
| context7 | Morph 插件自带 | 库文档查询 |
| websearch (Exa) | Morph 插件自带 | 网络搜索 |
| warpgrep | Morph 插件自带 | GitHub 源码搜索 |

### 插件列表

```
@morphllm/opencode-morph-plugin   — 高级编辑引擎（Morph edit, warpgrep等）
oh-my-openagent@latest            — Agent 编排系统
opencode-pty                       — 伪终端支持
opencode-token-monitor             — Token 用量监控
opencode-supermemory               — 持久化记忆系统
opencode-acp                       — ACP 协议
```

### 权限规则

项目级 `opencode.jsonc` 允许的常见操作：
- `docker *`、`docker-compose *`、`git *`
- `curl`、`pip`、`npm` 等开发工具
- `nvidia-smi` 等硬件诊断

---

## 三、Docker 推理服务部署

参见 [`machine/README.md`](machine/README.md) 详细说明。

### 快速启动

```bash
cd ~/.dotfiles/machine
cp docker-compose.template.yaml docker-compose.yaml
# 编辑 docker-compose.yaml，填入：
#   - MODELS_DIR: .gguf 文件所在目录
#   - MODEL_GPU0 / MODEL_GPU1: 模型文件名
#   - GPU0_DEVICES / GPU1_DEVICES: CUDA 设备 ID
docker compose up -d
```

### 典型架构

```
┌─────────────┐    ┌──────────────┐    ┌───────────┐
│  GPU0 (Cuda0)│    │  GPU1 (Cuda1) │    │ Ollama    │
│  llama.cpp   │    │  llama.cpp    │    │ (optional)│
│  Qwen 27B    │    │  Qwen 35B     │    │           │
│  port 11434  │    │  port 15433   │    │           │
└──────┬───────┘    └──────┬────────┘    └───────────┘
       │                    │
       └─────────┬──────────┘
                 │
          OpenCode (本机)
```

---

## 四、在新机器上适配

每台机器的 GPU 型号、VRAM、模型路径可能不同，需调整：

### 1. `docker-compose.yaml`

| 参数 | 含义 | 典型值 |
|------|------|--------|
| `MODELS_DIR` | .gguf 文件目录 | `/data/models` |
| `MODEL_GPU0` | GPU0 模型文件名 | `Qwen3.6-27B-UD-Q4_K_XL.gguf` |
| `CTX_SIZE_GPU0` | GPU0 上下文窗口 | `65536` ~ `262144` |
| `GPU0_DEVICES` | GPU0 设备号 | `0` |

### 2. `SUPERMEMORY_API_KEY`

如果使用 Supermemory 的远端同步功能，需要在 `supermemory.jsonc` 或环境变量中配置对应密钥。

### 3. DEEPSEEK_API_KEY

每个 DeepSeek 账户有独立的 API Key，不做跨机器共享。

---

## 五、维护指南

### 更新配置

```bash
cd ~/.dotfiles
git pull
bash install.sh          # 重新软链 + npm install
codebase-memory-mcp update   # 更新 codebase-memory-mcp 二进制
```

### 回滚

```bash
# 软链指向 dotfiles 仓库，回滚只需切换 git 版本
cd ~/.dotfiles && git checkout <previous-commit>
bash install.sh
```

---

## 六、常见问题

**Q: OpenCode 启动后看不到 codebase-memory-mcp 的工具？**
A: 需要重启 OpenCode 会话。MCP 服务器在启动时加载。

**Q: 怎么确认 MCP 连接正常？**
A: OpenCode 中运行 `list_mcp_resources()` 或类似命令查看可用工具。

**Q: 旧机器上的 gitnexus 索引怎么迁移？**
A: `.gitnexus/` 目录在项目根目录下，提交到 git 或拷贝即可。MCP 只是接口，数据独立。

**Q: install.sh 报错 "npm install 失败"？**
A: 确认 Node.js >= 18，并检查网络能否访问 npm registry。可尝试 `npm config set registry https://registry.npmmirror.com`。
