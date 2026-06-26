#!/usr/bin/env bash
# =============================================================================
# Sync Ollama model files to a shared models directory via symlinks
# =============================================================================
# Usage:
#   ./ollama-sync-models.sh
#
# Dependencies:
#   - Ollama container must be running
#   - Requires sudo for symlink creation (files owned by ollama user)
# =============================================================================
set -euo pipefail

OLLAMA_HOST_DIR="${OLLAMA_HOST_DIR:-/opt/ollama}"
MODELS_DIR="${MODELS_DIR:-./models}"
CONTAINER_NAME="${CONTAINER_NAME:-ollama}"

sudo mkdir -p "$MODELS_DIR"

echo "==> Syncing Ollama models to $MODELS_DIR ..."

docker exec "$CONTAINER_NAME" ollama list 2>/dev/null | awk 'NR>1 {print $1}' | while read -r model; do
    inner_path=$(docker exec "$CONTAINER_NAME" ollama show --modelfile "$model" | grep "^FROM " | awk '{print $2}' | tr -d '\r')

    if [ -z "$inner_path" ]; then
        continue
    fi

    actual_host_path="${inner_path/\/root\/.ollama/$OLLAMA_HOST_DIR}"

    if [ ! -f "$actual_host_path" ]; then
        echo "  [SKIP] $model → $actual_host_path not found"
        continue
    fi

    clean_name=$(echo "$model" | tr ':' '_' | tr '/' '_').gguf
    sudo ln -sf "$actual_host_path" "$MODELS_DIR/$clean_name"

    echo "  [LINK] $model → $clean_name"
done

# Clean broken symlinks
sudo find "$MODELS_DIR" -xtype l -delete

echo "==> Done."
