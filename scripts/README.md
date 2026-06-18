# Scripts

```
scripts/
  config.sh             # BOARD_* + EDGE_ROOT (~/Edge on Jetson)
  catalog.list          # injected edge scripts (inject/reject)
  host/                 # install, inject, reject, remote_ssh, uninstall
  edge/                 # scripts that run on the Jetson only
    connect_wifi
```

Host commands try **LAN first, then USB** automatically — no `usb` argument needed.

---

## Quick start

```bash
cd ~/Documents/Github/Edge/scripts
./host/install && nano config.sh
./host/inject connect_wifi
./host/remote_ssh edge
cd ~/Edge && ./connect_wifi
```

---

## Host commands

| Command | What it does |
|---------|----------------|
| `./host/install` | chmod host scripts |
| `./host/inject <name>` | inject edge script into `~/Edge` + update catalog |
| `./host/reject <name>` | remove from edge + catalog |
| `./host/reject --all` | reject all + clear catalog |
| `./host/remote_ssh [edge]` | SSH into Jetson (LAN, then USB) |
| `source ./host/uninstall` | reject all on edge + delete host repo |

---

## `edge/`

Scripts here run **only on the Jetson** (injected to `~/Edge`).

| Script | Purpose |
|--------|---------|
| `connect_wifi` | Scan, pick, and connect to Wi-Fi |

Add to `edge/`, then `./host/inject <name>`.

[← Host README](./host/README.md)
