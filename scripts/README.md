# Scripts

Host-managed ops for a Jetson edge device. You develop and version scripts on your **host** (laptop/PC), **inject** them to the Jetson, run them **on the edge**, and use a **catalog** to track what was deployed so **reject** / **uninstall** can tear things down safely.

## Layout

```
scripts/
  config.sh         # board IP, user, install path (edit once)
  catalog.list      # inject log + declared spawns (host source of truth)
  host/             # run on host — inject, reject, SSH, uninstall
    function/       # shared bash library (not run directly)
  edge/             # run on Jetson after inject (copied to ~/Edge)
```

| Area | README |
|------|--------|
| Host commands, catalog, inject/reject flow | [host/README.md](./host/README.md) |
| Edge scripts, spawns, running on the Jetson | [edge/README.md](./edge/README.md) |

## Architecture

```
  HOST (laptop)                         EDGE (Jetson)
  ─────────────                         ─────────────

  scripts/edge/<name>  ──inject──►      ~/Edge/<name>
       │                                     │
       │ # spawn lines                       │ (you run manually)
       ▼                                     ▼
  scripts/catalog.list                 apt / pip / files
       │
       │ reject / uninstall reads catalog
       ▼
  teardown spawns + remove script on edge
```

1. **Inject** copies an edge script to the Jetson and appends an entry to `catalog.list`. `# spawn` lines in the script header are logged as `> KIND ITEM` rows under that entry.
2. **Running** the script on the Jetson is separate — inject does not execute it.
3. **Reject** removes the script file on the edge and attempts to undo catalog spawns (skipping anything not installed).
4. **Uninstall** rejects everything, then optionally deletes the host repo clone.

Connectivity: host commands try **LAN** (`BOARD_IP`) first, then **USB gadget** (`BOARD_IP_USB`).

## Quick start

From the repo root (Git Bash on Windows, or bash on Linux/macOS):

```bash
cd scripts
./host/install
nano config.sh
```

```bash
./host/inject connect_wifi
./host/inject default_setup
./host/catalog list
./host/remote_ssh
```

On the Jetson:

```bash
cd ~/Edge
./connect_wifi
./default_setup
```

## Catalog format

`catalog.list` is the single source of truth for what the host believes is on the edge:

```
dd/mm/yy--HH:MM-- | SCRIPT  PATH
> KIND  ITEM  [EXTRA]
```

Example after injecting `default_setup`:

```
19/06/26--00:21-- | default_setup  ~/Edge
> apt  python3-pip
> pip  jetson-stats
```

- **Entry** — script name and install path on the Jetson.
- **Spawn** — side effects the script *may* cause (from `# spawn` lines in the edge script). Used on reject/uninstall; items not present on the device are skipped.

## Command index

| Command | Where | Purpose |
|---------|-------|---------|
| `./host/install` | host | `chmod +x` host entry scripts |
| `./host/inject <name>` | host | copy `edge/<name>` to Jetson + update catalog |
| `./host/reject <name>` | host | remove script + spawns + catalog block |
| `./host/reject --all` | host | remove all catalog entries (LAN → USB) |
| `./host/catalog list` | host | show `catalog.list` |
| `./host/remote_ssh [user]` | host | SSH to Jetson (LAN then USB) |
| `source ./host/uninstall` | host | reject all + delete repo + `cd ~` |
| `./edge/<name>` | Jetson | run after inject (e.g. `~/Edge/connect_wifi`) |

See [host/README.md](./host/README.md) and [edge/README.md](./edge/README.md) for full instruction sets and examples.
