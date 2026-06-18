# Host scripts

| Script | Purpose |
|--------|---------|
| [`install`](./install) | `chmod +x` all host scripts |
| [`inject`](./inject) | Inject `edge/<name>` onto the Jetson + update `catalog.list` |
| [`reject`](./reject) | Remove from edge + update `catalog.list` |
| [`remote_ssh`](./remote_ssh) | SSH into the Jetson |
| [`uninstall`](./bash/uninstall) | Reject all on edge, delete host repo, `cd ~` |

Use **source** so your terminal returns home after the repo is deleted:

```bash
source ./host/bash/uninstall
```

```bash
./host/install && nano config.sh
./host/inject connect_wifi usb
./host/remote_ssh edge usb
./host/reject connect_wifi usb
./host/reject --all usb
```

[← Back to scripts overview](../README.md)
