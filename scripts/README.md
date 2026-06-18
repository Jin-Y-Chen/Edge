# Scripts

```
scripts/
  config.sh
  catalog.list        # injected edge scripts (inject/reject)
  host/
    bash/             # install, inject, reject, remote_ssh, uninstall
    function/         # helper.sh
  edge/               # scripts that run on the Jetson only
    connect_wifi
```

---

## Quick start

```bash
cd ~/Documents/Github/Edge/scripts
./host/bash/install && nano config.sh
./host/bash/inject connect_wifi usb
./host/bash/remote_ssh edge usb
cd ~/edge-scripts && ./connect_wifi
```

---

## Host commands

| Command | What it does |
|---------|----------------|
| `./host/bash/install` | chmod host scripts |
| `./host/bash/inject <name> [usb]` | inject edge script + update catalog |
| `./host/bash/reject <name> [usb]` | remove from edge + catalog |
| `./host/bash/reject --all [usb]` | reject all + clear catalog |
| `./host/bash/remote_ssh edge [usb]` | SSH into Jetson |
| `source ./host/bash/uninstall [usb]` | reject all on edge + delete host repo |

---

## `edge/`

Scripts here run **only on the Jetson**.

| Script | Purpose |
|--------|---------|
| `connect_wifi` | Scan, pick, and connect to Wi-Fi |

Add to `edge/`, then `./host/bash/inject <name>`.

[← Host README](./host/README.md)
