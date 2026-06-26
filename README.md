# dotfiles

OpenCode 配置、插件、MCP 服务的一键引导安装。

## 包含内容

| 资产 | 说明 |
|------|------|
| `config/opencode/opencode.json` | 全局配置：providers、MCP、plugins |
| `config/opencode/oh-my-openagent.json` | Agent→模型映射配置 |
| `config/opencode/acp.jsonc` | ACP 协议配置 |
| `config/opencode/supermemory.jsonc` | 持久化记忆配置 |
| `config/opencode/AGENTS.md` | codebase-memory-mcp 指令 |
| `config/opencode/package.json` | 插件依赖清单 |
| `config/opencode/skill/` | 自定义 skills |

## 快速安装

```bash
git clone git@github.com:Mindlx/dotfiles.git ~/.dotfiles
cd ~/.dotfiles && bash install.sh
```

## 前置条件

- Node.js >= 18（用于 npm install）
- GitHub token 或个人 token（如果用到私有仓库）
- DEEPSEEK_API_KEY 环境变量（建议写入 `~/.bashrc` 或 `~/.zshrc`）

```bash
# 在 ~/.bashrc 或 ~/.zshrc 中添加：
export DEEPSEEK_API_KEY="sk-your-key"
```
