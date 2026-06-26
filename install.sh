#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}"

echo "==> 1. Linking opencode config..."
mkdir -p "$CONFIG_DIR"/opencode

# Symlink each file (skip node_modules)
for f in "$REPO_DIR"/config/opencode/*.json "$REPO_DIR"/config/opencode/*.jsonc "$REPO_DIR"/config/opencode/*.md; do
    [ -f "$f" ] && ln -sf "$f" "$CONFIG_DIR/opencode/$(basename "$f")"
done

# Symlink plugin dir
if [ -d "$REPO_DIR"/config/opencode/plugin ]; then
    mkdir -p "$CONFIG_DIR"/opencode/plugin
    for f in "$REPO_DIR"/config/opencode/plugin/*; do
        [ -f "$f" ] && ln -sf "$f" "$CONFIG_DIR/opencode/plugin/$(basename "$f")"
    done
fi

# Symlink skill dir
if [ -d "$REPO_DIR"/config/opencode/skill ]; then
    mkdir -p "$CONFIG_DIR"/opencode/skill
    for f in "$REPO_DIR"/config/opencode/skill/*; do
        [ -d "$f" ] && ln -sfn "$f" "$CONFIG_DIR/opencode/skill/$(basename "$f")"
    done
fi

# Symlink command dir
if [ -d "$REPO_DIR"/config/opencode/command ]; then
    mkdir -p "$CONFIG_DIR"/opencode/command
    for f in "$REPO_DIR"/config/opencode/command/*; do
        [ -f "$f" ] && ln -sf "$f" "$CONFIG_DIR/opencode/command/$(basename "$f")"
    done
fi

echo "==> 2. Installing plugin dependencies..."
cd "$CONFIG_DIR"/opencode
if [ -f package.json ]; then
    npm install
else
    echo "    package.json not found, skipping."
fi

echo "==> 3. Installing OpenSpec CLI..."
if command -v openspec &>/dev/null; then
    echo "    Already installed."
else
    npm install -g @fission-ai/openspec@latest
fi

echo "==> 4. Installing codebase-memory-mcp..."
if command -v codebase-memory-mcp &>/dev/null; then
    echo "    Already installed, checking update..."
    codebase-memory-mcp update 2>/dev/null || true
else
    curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
fi

echo ""
echo "==> Done!"
echo ""
echo "Next steps:"
echo "  1. Restart your shell: source ~/.bashrc"
echo "  2. Set DEEPSEEK_API_KEY in your shell profile:"
echo '       echo '"'"'export DEEPSEEK_API_KEY="sk-your-key"'"'"' >> ~/.bashrc'
echo "  3. Restart OpenCode"
echo ""
echo "Already have OpenCode installed? Just restart it - all configs are linked."
