# Scripts

Host-managed ops for the Jetson: scripts live on the laptop, get injected to the edge, run manually on the device, and `catalog.list` tracks what reject/uninstall should remove.

## Layout

```
scripts/
  config.sh         # BOARD_IP, BOARD_USER, EDGE_ROOT
  catalog.list      # inject log + spawns (host source of truth)
  host/             # run on laptop
  edge/             # copied to ~/Edge on Jetson
```

## Architecture

```
  HOST (laptop)                         EDGE (Jetson)
  ─────────────                         ─────────────

  scripts/edge/<name>  ──inject──►      ~/Edge/<name>
       │                                     │
       │ # spawn lines in script header      │ run manually
       ▼                                     ▼
  scripts/catalog.list                 nmcli, apt, pip, …
       │
       │ reject / uninstall
       ▼
  teardown spawns + rm script on edge
```

1. **Inject** — copy script to Jetson, write `catalog.list` entry, log `# spawn` lines as `> KIND ITEM`.
2. **Run** — separate step on the Jetson; inject does not execute anything.
3. **Reject** — undo catalog spawns in order (pip → git/dir → apt), with post-cleanup (`pip cache purge`, `daemon-reload`, `apt autoremove`, `apt autoclean`); removes script and catalog entry only if every step succeeds.
4. **Uninstall** — reject all, optionally delete host repo.

Host connectivity: **LAN** (`BOARD_IP`) first, **USB** (`BOARD_IP_USB`) second.

## Quick start

```bash
cd scripts
./host/install
nano config.sh
./host/inject connect_wifi
./host/inject default_setup
./host/remote_ssh
```

```bash
cd ~/Edge && ./connect_wifi && ./default_setup
```

## Catalog format

```
dd/mm/yy--HH:MM-- | SCRIPT  PATH
> KIND  ITEM  [EXTRA]
```

Spawns come from `# spawn KIND ITEM` comments in the edge script header — logged at inject, used at reject.

## Command index

| Command | Where | Purpose |
|---------|-------|---------|
| `./host/install` | host | `chmod +x` host scripts |
| `./host/inject <name>` | host | copy to Jetson + catalog |
| `./host/reject <name>` | host | remove script + spawns |
| `./host/reject --all` | host | remove all entries |
| `cat catalog.list` | host | view inject log for reject/uninstall |
| `./host/remote_ssh` | host | SSH to Jetson |
| `./host/remote_sshfs` | host | sshfs mount Jetson root |
| `./host/uninstall` | host | reject all + delete repo |
| `./<name>` | Jetson | run injected script |

Per-script raw commands: [host/README.md](./host/README.md), [edge/README.md](./edge/README.md).
