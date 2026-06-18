# Scripts

```
scripts/
  config.sh
  catalog.list        # injected edge scripts (inject/reject)
  host/               # install, inject, reject, remote_ssh, uninstall
  edge/               # scripts that run on the Jetson only
    connect_wifi
```

---

## Quick start

```bash
cd ~/Documents/Github/Edge/scripts
./host/install && nano config.sh
./host/inject connect_wifi usb
./host/remote_ssh edge usb
cd ~/edge-scripts && ./connect_wifi
```

---

## `edge/`

Scripts here run **only on the Jetson**. The host injects them via `./host/inject <name>`.

| Script | Purpose |
|--------|---------|
| `connect_wifi` | Scan, pick, and connect to Wi-Fi |

Add new edge scripts to `edge/`, then `./host/inject <name>`.

---

## `catalog.list`

Tracks what's injected:

```
connect_wifi  ~/edge-scripts
```

[← Host README](./host/README.md)
