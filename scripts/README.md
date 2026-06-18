# Scripts

Bash helpers for Jetson ops. Run from **Git Bash**, **WSL**, or Linux/Mac.

```bash
cd Edge/scripts
chmod +x setup_scripts && ./setup_scripts   # once after clone
./remote_ssh edge usb
```

## Config

Edit [`config.sh`](./config.sh) once for your board:

| Variable | Default | Description |
|----------|---------|-------------|
| `BOARD_USER` | `edge` | SSH username |
| `BOARD_IP` | `192.168.1.28` | LAN / Wi-Fi |
| `BOARD_IP_USB` | `192.168.55.1` | USB gadget |

Override at runtime: `BOARD_IP=10.0.0.5 ./remote_ssh edge`

---

## `setup_scripts`

Chmods every script in this folder. Only `setup_scripts` needs manual chmod first.

```bash
chmod +x setup_scripts && ./setup_scripts
# or: bash setup_scripts
```

Runs: `chmod +x` on all files except `README.md`

---

## `remote_ssh`

SSH into the Jetson from your host.

| Command | Runs |
|---------|------|
| `./remote_ssh` | `ssh edge@192.168.1.28` |
| `./remote_ssh edge usb` | `ssh edge@192.168.55.1` |
| `./remote_ssh -X` | `ssh -X edge@<ip>` |
| `./remote_ssh -n jetson` | `ssh jetson@192.168.1.28` |

Args: `[name] [usb] [-X]` — `name` = SSH user, `usb` = USB gadget IP

---

## `connect_wifi`

Connect Jetson to Wi-Fi via SSH — same USB/LAN options as `remote_ssh`.

| Command | What it does |
|---------|----------------|
| `./connect_wifi usb` | scan → pick → password (over USB) |
| `./connect_wifi` | same over LAN |
| `./connect_wifi list usb` | show networks visible to the board |
| `./connect_wifi usb "SSID" "pass"` | direct connect |

Runs over SSH: `nmcli device wifi rescan` → pick → `sudo nmcli device wifi connect` → `hostname -I`

**Windows — get saved Wi-Fi password:**

```powershell
netsh wlan show profile name="SSID" key=clear
```

---

## Typical workflow

```bash
./remote_ssh edge usb
./connect_wifi usb              # pick network + enter password
BOARD_IP=<new-ip> ./remote_ssh edge   # or update config.sh
```
