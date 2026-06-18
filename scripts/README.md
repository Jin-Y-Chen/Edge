# Scripts

Overview for all Jetson helper scripts. **Details live in each folder's README.**

```
scripts/
  config.sh       # shared settings — edit on host
  host/           # run from laptop        → host/README.md
  edge/           # run on Jetson          → edge/README.md
```

| Folder | Terminal | README |
|--------|----------|--------|
| [`host/`](./host/) | Host (laptop) | [host/README.md](./host/README.md) |
| [`edge/`](./edge/) | Edge (Jetson) | [edge/README.md](./edge/README.md) |

On Windows, use **Git Bash** or **WSL** for bash scripts.

---

## Why two folders?

| | Host | Edge |
|---|------|------|
| **Machine** | Your laptop/PC | Jetson Orin Nano |
| **Has git repo?** | Yes — clone once, `git pull` | No — copy `edge/` bundle when needed |
| **Purpose** | SSH into the board | Run commands on the board (Wi-Fi, tuning) |
| **Setup** | `./host/install` on host | `scp` then `./install` on edge |
| **Teardown** | `./host/uninstall` → delete repo clone | `./uninstall` scans and removes all bundles |

---

## `config.sh`

Used by **host** scripts only (`remote_ssh`). Edit on your laptop:

| Variable | Default | Description |
|----------|---------|-------------|
| `BOARD_USER` | `edge` | SSH username on the edge node |
| `BOARD_IP` | `192.168.1.28` | Edge address over LAN / Wi-Fi |
| `BOARD_IP_USB` | `192.168.55.1` | Edge address over USB-C gadget |

```bash
nano config.sh
BOARD_IP=10.0.0.42 ./host/remote_ssh edge
```

---

## Quick start

```bash
cd ~/Documents/Github/Edge/scripts
chmod +x host/install && ./host/install
nano config.sh

# Host — copy edge bundle, SSH over USB
scp -r edge/* edge@192.168.55.1:~/edge-scripts/
./host/remote_ssh edge usb

# Edge — Wi-Fi
cd ~/edge-scripts && ./install && ./connect_wifi

# Host — SSH over Wi-Fi
nano config.sh    # set BOARD_IP
./host/remote_ssh edge
```

---

## Where to read more

- **Host** (`install`, `remote_ssh`) → [host/README.md](./host/README.md)
- **Edge** (`install`, `uninstall`, `connect_wifi`) → [edge/README.md](./edge/README.md)
- **Raw commands** → [docs/jetson-config-command.txt](../docs/jetson-config-command.txt)

---