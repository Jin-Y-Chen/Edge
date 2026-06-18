# Host scripts

```
host/
  bash/                 # run from laptop
    install
    inject
    reject
    remote_ssh
    uninstall
  function/
    helper.sh           # shared helpers (not run directly)
```

| Script | Purpose |
|--------|---------|
| [`bash/install`](./bash/install) | `chmod +x` all scripts in `host/bash/` |
| [`bash/inject`](./bash/inject) | Inject `edge/<name>` onto the Jetson + update `catalog.list` |
| [`bash/reject`](./bash/reject) | Remove from edge + update `catalog.list` |
| [`bash/remote_ssh`](./bash/remote_ssh) | SSH into the Jetson |
| [`bash/uninstall`](./bash/uninstall) | Reject all on edge, delete host repo, `cd ~` |

---

## Workflow

```bash
cd ~/Documents/Github/Edge/scripts
./host/bash/install && nano config.sh

./host/bash/inject connect_wifi usb
./host/bash/remote_ssh edge usb
cd ~/edge-scripts && ./connect_wifi

./host/bash/reject connect_wifi usb
./host/bash/reject --all usb
```

**Uninstall** — use `source` so your terminal returns to `$HOME`:

```bash
source ./host/bash/uninstall
```

[← Back to scripts overview](../README.md)
