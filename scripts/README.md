# Scripts

```
scripts/
  config.sh
  catalog.list
  host/*.sh         # run on laptop
  edge/*.sh         # run on Jetson (injected to ~/Edge)
```

Host commands try **LAN first, then USB**.

## Deploy

```bash
cd scripts
./host/install.sh && nano config.sh
./host/inject.sh connect_wifi
./host/remote_ssh.sh edge
# on Jetson:
cd ~/Edge && ./connect_wifi.sh
```

## Commands

| Command | Purpose |
|---------|---------|
| `./host/install.sh` | chmod host scripts |
| `./host/inject.sh <name>` | copy `edge/<name>.sh` to Jetson `~/Edge` |
| `./host/reject.sh <name>` | remove one entry from Jetson + catalog |
| `./host/reject.sh --all` | remove all (LAN → USB) |
| `./host/remote_ssh.sh [user]` | SSH to Jetson |
| `source ./host/uninstall.sh` | reject all + delete repo + `cd ~` |

Names omit `.sh` on the command line (`connect_wifi` → `edge/connect_wifi.sh`).
