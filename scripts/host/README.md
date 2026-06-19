# Host scripts

Run these from your **host machine** (the laptop/PC that SSHs into the Jetson). All commands live under `scripts/host/` and share a common library in `scripts/host/function/`.

## Prerequisites

- Bash (Git Bash on Windows is supported)
- SSH client
- Jetson reachable on LAN and/or USB (`config.sh`)
- From `scripts/`:

```bash
./host/install
```

`install` only makes host entry scripts executable. It does not touch the Jetson.

## Configuration

Edit `scripts/config.sh` before the first inject:

```bash
nano ../config.sh
```

```bash
BOARD_USER="${BOARD_USER:-edge}"
BOARD_IP="${BOARD_IP:-192.168.1.28}"        # LAN
BOARD_IP_USB="${BOARD_IP_USB:-192.168.55.1}" # USB gadget
EDGE_ROOT="${EDGE_ROOT:-~/Edge}"             # inject target on Jetson
```

| Variable | Purpose |
|----------|---------|
| `BOARD_USER` | SSH user on the Jetson |
| `BOARD_IP` | LAN address (tried first) |
| `BOARD_IP_USB` | USB gadget address (fallback) |
| `EDGE_ROOT` | Default directory for injected scripts |

## How host commands work

```
  config.sh ──► host_init() ──► pick_route() ──► board_ssh / board_scp
                     │                │
                     ▼                ▼
               catalog.list      LAN, then USB
```

1. Each entry script sources `function/host.sh` and calls `host_init`.
2. `host_init` loads `config.sh`, sets paths to `catalog.list` and `edge/`.
3. Commands that talk to the Jetson call `pick_route` (port 22 on LAN, then USB).
4. **Key-based SSH** — multiple `ssh`/`scp` calls per operation.
5. **Password SSH** — inject uses one interactive SSH session to upload the file; reject/uninstall may prompt once per session for multi-step teardown.

Stale host keys in `known_hosts` are cleared automatically when the board IP changes.

## Library modules (`function/`)

Not run directly — loaded by `host.sh`:

| File | Role |
|------|------|
| `host.sh` | Entry point, `host_init`, loads modules |
| `util.sh` | `die`, `confirm_yes`, line trimming |
| `board.sh` | IP/route, port probe, host-key cleanup |
| `ssh.sh` | SSH session, `board_ssh`, `board_scp`, single-SSH inject |
| `catalog.sh` | Read/write `catalog.list`, spawn parsing |
| `spawn.sh` | Teardown apt/pip/git/dir from catalog on reject |
| `edge.sh` | Discover scripts in `scripts/edge/` |
| `inject.sh` | `inject_script` workflow |
| `reject.sh` | `reject_one`, `reject_all_catalog` |

## Commands

### `install`

```bash
cd scripts
./host/install
```

Makes `inject`, `reject`, `catalog`, `remote_ssh`, `uninstall` executable.

---

### `inject <name>`

Copies `scripts/edge/<name>` to the Jetson, logs the entry in `catalog.list`, and records `# spawn` lines from the script header.

```bash
cd scripts
./host/inject connect_wifi
./host/inject default_setup
```

Without an argument, lists available edge scripts and current catalog:

```bash
./host/inject
```

**What inject does**

1. Resolve install path (`EDGE_ROOT` or existing catalog path for that name).
2. Reach the board (LAN → USB).
3. Upload script (key auth: `mkdir` + `scp` + `chmod`; password auth: one SSH heredoc).
4. Append/update catalog entry with timestamp.
5. Parse `# spawn KIND ITEM` lines from the edge script → write `> KIND ITEM` rows in `catalog.list`.
6. Print updated catalog.

Inject does **not** run the script on the Jetson.

**Re-inject** updates the timestamp and adds any new spawn lines not already in the catalog.

---

### `reject <name>`

Removes one injected script: teardown catalog spawns (if any), delete `~/Edge/<name>` on the edge, remove catalog block.

```bash
cd scripts
./host/reject default_setup
```

Prompts for confirmation unless you passed `-y` (not exposed on single reject — use interactive confirm).

**Spawn teardown** (from catalog, not from running the script):

- `apt` — remove package if `dpkg -s` says installed
- `pip` — uninstall if `pip3 show` finds it
- `git` / `dir` — `rm -rf` if path exists

If the edge script was never run, spawns are skipped with a message.

---

### `reject --all`

Removes every catalog entry (LAN, then USB).

```bash
./host/reject --all          # confirms interactively
./host/reject --all -y       # no confirm
```

---

### `catalog list`

Shows `scripts/catalog.list` (comments + entries + spawns).

```bash
./host/catalog list
```

---

### `remote_ssh`

Opens an interactive SSH session. Tries LAN first, then USB.

```bash
./host/remote_ssh
./host/remote_ssh edge
./host/remote_ssh -X          # X11 forwarding
```

---

### `uninstall`

**Must be sourced** (not executed) so your shell can `cd ~` after repo deletion.

```bash
cd scripts
source ./host/uninstall
```

Steps:

1. Confirm reject-all on the edge (removes scripts + spawns per catalog).
2. Confirm delete of the host repo clone.
3. `cd ~`

If edge cleanup fails, the host repo is kept.

## Typical workflows

### First deploy

```bash
cd scripts
./host/install
nano config.sh

./host/inject connect_wifi
./host/inject default_setup
./host/catalog list
./host/remote_ssh
```

On Jetson:

```bash
cd ~/Edge
./connect_wifi
./default_setup
sudo jtop
```

### Update an edge script

Edit `scripts/edge/<name>`, then re-inject:

```bash
./host/inject connect_wifi
```

### Remove one script from the edge

```bash
./host/reject default_setup
./host/catalog list
```

### Tear down everything

```bash
./host/reject --all
# or full host + edge cleanup:
source ./host/uninstall
```

## Catalog responsibilities (host)

| Action | `catalog.list` change |
|--------|------------------------|
| `inject <name>` | Add/update `\| name path` + spawn rows from `# spawn` in edge script |
| `reject <name>` | Remove name block (entry + its `>` lines) |
| `reject --all` | Clear all entries |
| Manual edit | Not recommended — host tools assume this file is authoritative |

## Troubleshooting

| Issue | What to try |
|-------|-------------|
| `Could not reach board` | Check USB cable / LAN; verify `BOARD_IP` / `BOARD_IP_USB` in `config.sh` |
| `Host key verification failed` | Re-run command — stale key is removed automatically |
| `Permission denied (publickey,password)` | Enter SSH password when prompted, or set up keys: `ssh-copy-id edge@<ip>` |
| Catalog empty after manual copy to Jetson | Run `./host/inject <name>` — copy alone does not update the catalog |
| Spawns missing in catalog | Add `# spawn` lines to edge script header, re-inject |
