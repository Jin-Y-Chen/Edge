# Host scripts

Run from the laptop against the Jetson. Commands SSH over LAN first, then USB (`config.sh`). Shared code lives in `function/` — those files are not run directly.

Overview: [../README.md](../README.md) · Edge scripts: [../edge/README.md](../edge/README.md)

## Setup

```bash
cd scripts
./host/install
nano config.sh
```

`config.sh`:

```bash
BOARD_USER="${BOARD_USER:-edge}"
BOARD_IP="${BOARD_IP:-192.168.1.28}"
BOARD_IP_USB="${BOARD_IP_USB:-192.168.55.1}"
EDGE_ROOT="${EDGE_ROOT:-~/Edge}"
```

Route pick (used by most commands):

```bash
nc -z -w 5  $BOARD_IP 22      # LAN first
nc -z -w 10 $BOARD_IP_USB 22  # USB fallback
```

Stale host key:

```bash
ssh-keygen -R $BOARD_IP
```

---

## `install`

**Purpose** — Make host entry scripts executable after clone.

**Run**

```bash
cd scripts
./host/install
```

**Raw commands**

```bash
chmod +x scripts/host/inject scripts/host/reject scripts/host/catalog \
         scripts/host/remote_ssh scripts/host/uninstall scripts/host/install
```

Does not touch the Jetson.

---

## `inject`

**Purpose** — Copy an edge script to the Jetson and log it (plus `# spawn` lines) in `catalog.list`.

**Run**

```bash
cd scripts
./host/inject connect_wifi
./host/inject default_setup
./host/inject              # list edge scripts + catalog
```

**Raw commands on Jetson** (key auth — three SSH calls):

```bash
ssh edge@$BOARD_IP "mkdir -p ~/Edge"
scp scripts/edge/<name> edge@$BOARD_IP:~/Edge/
ssh edge@$BOARD_IP "chmod +x ~/Edge/<name>"
```

**Raw commands on Jetson** (password auth — one SSH session):

```bash
ssh edge@$BOARD_IP bash -s <<'EOF'
mkdir -p ~/Edge
base64 -d > ~/Edge/<name> <<'B64EOF'
<base64 of local file>
B64EOF
chmod +x ~/Edge/<name>
EOF
```

**Raw commands on host** (catalog)

- Append/update line: `dd/mm/yy--HH:MM-- | <name>  ~/Edge`
- Parse `# spawn KIND ITEM` from `edge/<name>` → append `> KIND  ITEM` under that entry

Does not execute the edge script on the Jetson.

---

## `reject`

**Purpose** — Remove one or all injected scripts from the Jetson, undo catalog spawns if present, update `catalog.list`.

**Run**

```bash
./host/reject default_setup
./host/reject --all
./host/reject --all -y
```

**Raw commands on Jetson** (per script, from catalog spawns — skipped if not installed)

```bash
# apt spawn
dpkg -s <package> && sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge <package>

# pip spawn
pip3 show <package> && sudo pip3 uninstall -y <package>

# git / dir spawn
[[ -e <path> ]] && rm -rf <path>
```

**Raw commands on Jetson** (always)

```bash
rm -f ~/Edge/<name>
```

**Raw commands on host**

- Remove script block from `catalog.list` (entry + its `>` spawn lines)

Tries LAN, then USB. Password SSH may prompt once for the session.

---

## `catalog`

**Purpose** — Show the inject log: which scripts are on the edge, where they live, and what spawns reject/uninstall will tear down.

**Run**

```bash
./host/catalog list
```

**Raw commands**

```bash
cat scripts/catalog.list    # read and print
```

---

## `remote_ssh`

**Purpose** — Open a shell on the Jetson.

**Run**

```bash
./host/remote_ssh
./host/remote_ssh edge
./host/remote_ssh -X
```

**Raw commands**

```bash
ssh -o ConnectTimeout=5  edge@$BOARD_IP      # LAN
ssh -o ConnectTimeout=10 edge@$BOARD_IP_USB   # USB if LAN closed
ssh -X edge@$BOARD_IP                         # with -X
```

---

## `uninstall`

**Purpose** — Reject everything on the edge, then delete the repo clone from the host.

**Run** (must source — not `./uninstall`)

```bash
cd scripts
source ./host/uninstall
```

**Raw commands**

Same as `reject --all` on the Jetson, then on the host:

```bash
rm -rf <repo-root>
cd ~
```

If edge cleanup fails, the repo is kept.

---

## `function/` library

| File | What it wraps |
|------|----------------|
| `host.sh` | `host_init`, loads modules |
| `util.sh` | `die`, `confirm_yes` |
| `board.sh` | IP, port probe, `ssh-keygen -R` |
| `ssh.sh` | `ssh`, `scp`/`cat` upload, inject heredoc |
| `catalog.sh` | read/write `catalog.list`, `# spawn` parsing |
| `spawn.sh` | build teardown script from catalog spawns |
| `edge.sh` | list files in `scripts/edge/` |
| `inject.sh` | inject workflow |
| `reject.sh` | reject workflow |

---

## Typical flow

```bash
cd scripts
./host/install && nano config.sh
./host/inject connect_wifi
./host/inject default_setup
./host/catalog list
./host/remote_ssh
```

On Jetson: `cd ~/Edge && ./connect_wifi && ./default_setup`

Teardown: `./host/reject default_setup` or `source ./host/uninstall`

---

## When things break

| Problem | Fix |
|---------|-----|
| Board unreachable | Cable, IP in `config.sh`, try USB |
| Host key changed | Re-run — script runs `ssh-keygen -R` |
| SSH permission denied | Password when prompted, or `ssh-copy-id edge@<ip>` |
| Catalog empty after manual copy | Run `./host/inject <name>` |
| Spawns missing | Add `# spawn` to edge script header, re-inject |
