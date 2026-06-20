# Modules (Docker)

Container workloads for the Jetson. Host bootstrap stays in `scripts/edge/` (`connect_wifi`, `default_setup`, `max_power`).

## Layout

```
module/
  compose.yaml              # all services
  camera/IMX/               # V4L2 / IMX capture
  gimbal/C-20T/             # serial gimbal
  power_supply/power_supply/ # external PSU monitor
  CUDA/                     # GPU health + optional LLM
```

## Prerequisites (host)

1. `~/Edge/connect_wifi`, `default_setup`, `max_power` already run
2. Camera driver + `/dev/video0` on host (not in container)
3. `sudo docker` available, NVIDIA Container Runtime (`--runtime=nvidia`)

Match `L4T_TAG` in each `Dockerfile` to your JetPack (see `sudo jtop` INFO page). Default: `r36.4.0`.

## Build and run

```bash
cd ~/Edge/module   # or clone path on Jetson

# one service
docker compose build camera-imx
docker compose up -d camera-imx

# all
docker compose build
docker compose up -d
```

## Per module

| Service | Device / env | Output |
|---------|----------------|--------|
| `camera-imx` | `--device /dev/video0`, `CAPTURE_MODE=opencv\|bayer` | `/tmp/edge_frame.png` |
| `gimbal-c20t` | `--device /dev/ttyUSB0`, `GIMBAL_PORT` | serial control |
| `power-supply` | `I2C_BUS=/dev/i2c-1` optional | stdout metrics |
| `cuda` | `--runtime=nvidia`, `RUN_LLM=1` optional | port 8080 |

### Camera (raw Bayer)

```bash
CAPTURE_MODE=bayer FRAME_WIDTH=1920 FRAME_HEIGHT=1200 docker compose up camera-imx
```

### CUDA (LLM server)

Uses pre-built image pattern from `docs/jetson-config-command.txt`, or set `RUN_LLM=1` after installing `llama-server` in the image:

```bash
RUN_LLM=1 CUDA_PORT=8080 docker compose up cuda
curl http://localhost:8080/health
```

## Host vs container

| Task | Where |
|------|-------|
| Wi-Fi, SSH, jtop, nvpmodel, fan | `scripts/edge/` on host |
| Camera driver, jetson-io | host (once) |
| Capture, gimbal, inference | `module/` containers |
