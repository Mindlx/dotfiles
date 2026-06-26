# machine/ — Machine-level deployment templates

Reusable templates for Docker-based AI inference environments.

## Contents

| File | Description |
|------|-------------|
| `docker-compose.template.yaml` | Docker Compose for llama.cpp (multi-GPU) + Ollama |
| `deploy/ollama-sync-models.sh` | Sync Ollama .gguf files to a shared models directory |

## Quick Start

```bash
# 1. Copy and customize
cp docker-compose.template.yaml docker-compose.yaml
# Edit docker-compose.yaml — set model paths, GPU IDs, ports

# 2. Start services
docker compose up -d

# 3. (Optional) Sync Ollama models to shared directory
bash deploy/ollama-sync-models.sh
```

## Customization Checklist

Search for `${...}` placeholders in `docker-compose.yaml`:

| Variable | Default | What to set |
|----------|---------|-------------|
| `MODELS_DIR` | `./models` | Absolute path to your .gguf files |
| `MODEL_GPU0` | — | GGUF filename for primary GPU |
| `MODEL_GPU1` | — | GGUF filename for secondary GPU |
| `GPU0_DEVICES` | `0` | CUDA device ID for GPU0 |
| `GPU1_DEVICES` | `1` | CUDA device ID for GPU1 |
| `LLAMA_PORT_GPU0` | `11434` | Host port for GPU0 service |
| `LLAMA_PORT_GPU1` | `15433` | Host port for GPU1 service |
| `CTX_SIZE_GPU0` | `131072` | Context window for GPU0 |
| `CTX_SIZE_GPU1` | `262144` | Context window for GPU1 |
| `OLLAMA_HOST_DIR` | `./ollama` | Host path to Ollama data |
| `DOCKER_NETWORK` | `docker_default` | Docker network name |
