"""CUDA availability check and optional inference server hook."""

import os
import subprocess
import sys


def cuda_health() -> dict:
    import torch

    available = torch.cuda.is_available()
    info: dict = {"cuda_available": available}
    if available:
        info["device_count"] = torch.cuda.device_count()
        info["device_name"] = torch.cuda.get_device_name(0)
        props = torch.cuda.get_device_properties(0)
        info["total_memory_gb"] = round(props.total_memory / (1024**3), 2)
    return info


def run_llama_server() -> None:
    """Start llama-server (same pattern as docs/jetson-config-command.txt)."""
    port = os.environ.get("CUDA_PORT", "8080")
    model = os.environ.get(
        "LLM_MODEL",
        "unsloth/gemma-4-E2B-it-GGUF:Q4_K_M",
    )
    threads = os.environ.get("LLM_THREADS", "6")
    gpu_layers = os.environ.get("LLM_GPU_LAYERS", "99")

    cmd = [
        "llama-server",
        "-hf",
        model,
        "--host",
        "0.0.0.0",
        "--port",
        port,
        "-t",
        threads,
        "--n-gpu-layers",
        gpu_layers,
    ]
    print("starting:", " ".join(cmd))
    subprocess.run(cmd, check=True)


def main() -> None:
    info = cuda_health()
    print("CUDA health:", info)
    if not info["cuda_available"]:
        sys.exit(1)

    if os.environ.get("RUN_LLM", "0").lower() in ("1", "true", "yes"):
        run_llama_server()
        return

    print("idle — set RUN_LLM=1 to start llama-server, or CUDA_PORT for health URL")
    import time

    while True:
        time.sleep(3600)


if __name__ == "__main__":
    main()
