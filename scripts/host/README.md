# Host scripts

Run these from your **host** terminal (laptop/PC) — Git Bash, WSL, or Linux/Mac.

These scripts connect your laptop **to** the edge node. They do not configure the board itself — that's [`../edge/`](../edge/).

---

## First-time setup

```bash
cd ~/Documents/Github/Edge/scripts
chmod +x host/install
./host/install
nano config.sh
```

Edit [`../config.sh`](../config.sh) with your board IP and SSH user before using `remote_ssh`.

---

## Files

| File | Purpose |
|------|---------|
| [`install`](./install) | `chmod +x` all scripts in `host/` |
| [`uninstall`](./uninstall) | Delete the Edge repo clone from your host |
| [`remote_ssh`](./remote_ssh) | Open an SSH session on the edge node |

All host scripts source [`../config.sh`](../config.sh).

Wi-Fi setup is [`../edge/connect_wifi`](../edge/connect_wifi) — runs on the Jetson, not here.

---

## `install`

**Run on: Host**

```bash
chmod +x host/install
./host/install
```

Chmods every file in `host/` except `README.md`.

---

## `uninstall`

**Run on: Host**

Deletes the entire Edge repo clone (including host scripts). Prompts before removing.

```bash
./host/uninstall
```

---

## `remote_ssh`

**Run on: Host** → **opens: Edge terminal**

SSH into the Jetson. Your shell prompt moves to the edge until you `exit`.

### Usage

```bash
./remote_ssh [name] [usb] [-X]
./remote_ssh --help
```

### Examples

```bash
# First connection over USB-C
./host/remote_ssh edge usb

# After Wi-Fi is configured (uses BOARD_IP from config.sh)
./host/remote_ssh edge

# Remote GUI apps (X11)
./host/remote_ssh edge usb -X

# Different SSH user
./host/remote_ssh -n jetson
```

### Commands executed

| You type | Runs |
|----------|------|
| `./remote_ssh` | `ssh edge@192.168.1.28` |
| `./remote_ssh edge usb` | `ssh edge@192.168.55.1` |
| `./remote_ssh -X` | `ssh -X edge@<ip>` |

Args: `[name]` = SSH user · `usb` = USB gadget IP · `-X` = X11 forwarding

---

## Typical host workflow

```bash
cd ~/Documents/Github/Edge/scripts

# Copy edge bundle over USB, then SSH in
scp -r edge/* edge@192.168.55.1:~/edge-scripts/
./host/remote_ssh edge usb

# On edge terminal:
cd ~/edge-scripts && ./install && ./connect_wifi

# Back on host — update IP, SSH over Wi-Fi
nano config.sh
./host/remote_ssh edge
```

[← Back to scripts overview](../README.md)
