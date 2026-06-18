# Host scripts

```
host/
  install
  inject
  reject
  remote_ssh
  uninstall
  function/
    helper.sh           # shared helpers (not run directly)
```

Injected scripts land on the Jetson at **`~/Edge`** (see `EDGE_ROOT` in `config.sh`).

| Script | Purpose |
|--------|---------|
| [`install`](./install) | `chmod +x` all scripts in `host/` |
| [`inject`](./inject) | Inject `edge/<name>` onto the Jetson + update `catalog.list` |
| [`reject`](./reject) | Remove from edge + update `catalog.list` |
| [`remote_ssh`](./remote_ssh) | SSH into the Jetson |
| [`uninstall`](./uninstall) | Reject all on edge, delete host repo, `cd ~` |

---

## Workflow

```bash
cd ~/Documents/Github/Edge/scripts
./host/install && nano config.sh

./host/inject connect_wifi usb
./host/remote_ssh edge usb
cd ~/Edge && ./connect_wifi

./host/reject connect_wifi usb
./host/reject --all usb
```

**Uninstall** — use `source` so your terminal returns to `$HOME`:

```bash
source ./host/uninstall
```

[← Back to scripts overview](../README.md)
