# Edge scripts

Run these on the **Jetson** (edge terminal) — not on your laptop.

This folder is a **bundle**: copy it to the board, `./install`, use it, `./uninstall` to remove everything.

---

## Getting the bundle onto the edge

```bash
# Host — copy over USB (before or after first SSH)
cd ~/Documents/Github/Edge/scripts
scp -r edge/* edge@192.168.55.1:~/edge-scripts/

# Host — SSH in
./host/remote_ssh edge usb
```

```bash
# Edge
cd ~/edge-scripts
chmod +x install
./install
```

Copy again when you add or update edge scripts in the repo.

---

## Files

| File | Purpose |
|------|---------|
| [`install`](./install) | `chmod +x` all scripts in this bundle |
| [`uninstall`](./uninstall) | Scan `$HOME` and remove every edge bundle |
| [`connect_wifi`](./connect_wifi) | Scan, pick, and connect to Wi-Fi on this board |

Edge scripts run locally on the Jetson — they do **not** use [`../config.sh`](../config.sh).

More commands: [docs/jetson-config-command.txt](../../docs/jetson-config-command.txt)

---

## `install`

**Run on: Edge**

```bash
cd ~/edge-scripts
chmod +x install
./install
```

Chmods every file in this folder except `README.md`.

---

## `uninstall`

**Run on: Edge**

Scans `$HOME` for edge bundles (folders with `install` + `uninstall`), lists them, then removes **all** matches after confirmation.

```bash
./uninstall
```

Example:

```
Edge bundles found:
  /home/edge/edge-scripts
  /home/edge/edge-bundle

Remove all 2 bundle(s)? [y/N] y
Removed /home/edge/edge-scripts
Removed /home/edge/edge-bundle
All edge bundles removed.
```

---

## `connect_wifi`

**Run on: Edge**

Scans networks visible to this board, shows a numbered list, prompts for password, connects via `nmcli`.

### Examples

```bash
# Edge — interactive (default)
./connect_wifi

# Edge — show scan table
./connect_wifi list

# Edge — direct connect
./connect_wifi "MyHomeWiFi" "mypassword"
```

### Commands executed (on edge)

```bash
nmcli device wifi rescan
nmcli -t -f SSID,SIGNAL device wifi list
sudo nmcli device wifi connect "SSID" password "pass"
hostname -I
```

**Get password from Windows host (PowerShell):**

```powershell
netsh wlan show profile name="MyHomeWiFi" key=clear
```

---

## Typical edge workflow

```bash
# Edge (after scp + SSH in)
cd ~/edge-scripts
./install
./connect_wifi          # pick network, enter password
hostname -I             # note IP for host config.sh

# Later — remove bundle entirely
./uninstall
```

---

## Adding new edge scripts

1. Add script to `scripts/edge/` on host
2. `git push`
3. `scp -r edge/* edge@<ip>:~/edge-scripts/`
4. On edge: `./install`

| Runs on laptop? | → [`../host/`](../host/) |
| Runs on Jetson? | → `edge/` (this folder) |

[← Back to scripts overview](../README.md)
