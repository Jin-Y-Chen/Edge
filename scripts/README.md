# Scripts

```
scripts/
  config.sh
  catalog.list
  host/           # run on laptop
  edge/           # run on Jetson (injected to ~/Edge)
```

Host commands try **LAN first, then USB**.

## Deploy

```bash
cd scripts
./host/install && nano config.sh
./host/inject connect_wifi
./host/remote_ssh edge
# on Jetson:
cd ~/Edge && ./connect_wifi
```

## Commands

| Command | Purpose |
|---------|---------|
| `./host/install` | chmod host scripts |
| `./host/inject <name>` | copy `edge/<name>` to Jetson `~/Edge` |
| `./host/reject <name>` | remove one entry from Jetson + catalog |
| `./host/reject --all` | remove all (LAN → USB) |
| `./host/remote_ssh [user]` | SSH to Jetson |
| `source ./host/uninstall` | reject all + delete repo + `cd ~` |
