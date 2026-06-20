# Host scripts

Host-side entry points for managing the Jetson. Run them from `scripts/host/` on the laptop; each command reaches the board over SSH — LAN (`BOARD_IP`) first, USB (`BOARD_IP_USB`) if LAN is down. Board IP and user come from `config.sh`. Implementation is in `function/` (sourced library, not executed on its own).

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
chmod +x scripts/host/inject scripts/host/reject \
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

Does not execute the edge script on the Jetson. Prints the updated catalog log when done.

---

## `reject`

**Purpose** — Remove one or all injected scripts from the Jetson, undo catalog spawns if present, update `catalog.list` only when teardown and script removal both succeed.

If any spawn step fails, the script file and catalog entry are left in place so you can fix the device and retry.

**Run**

```bash
./host/reject default_setup
./host/reject --all
./host/reject --all -y
```

**Raw commands on Jetson** (per script — order: pip → git/dir → apt → post-cleanup; skipped if not installed)

```bash
# pip spawn
pip3 show <package> && sudo systemctl stop <service> && sudo systemctl disable <service>
pip3 show <package> && sudo pip3 uninstall -y <package>
# after all pip spawns (automatic)
sudo pip3 cache purge 2>/dev/null || sudo rm -rf ~/.cache/pip /root/.cache/pip
sudo systemctl daemon-reload

# git / dir spawn
[[ -e <path> ]] && sudo rm -rf <path>

# apt spawn
dpkg -s <package> && sudo DEBIAN_FRONTEND=noninteractive apt-get remove -y --purge <package>
# after all apt spawns (automatic)
sudo DEBIAN_FRONTEND=noninteractive apt-get autoremove -y
sudo DEBIAN_FRONTEND=noninteractive apt-get autoclean -y
```

**Raw commands on Jetson** (always)

```bash
rm -f ~/Edge/<name>
```

**Raw commands on host**

- Remove script block from `catalog.list` (entry + its `>` spawn lines) — only after all spawns tear down and `rm` of the script succeeds

Tries LAN, then USB. Password SSH may prompt once for the session. Spawn teardown may prompt once for Jetson **sudo** (apt/pip/rm need root).

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

### Remote SSH via VS Code or Cursor

- `./host/remote_ssh` — terminal shell only.
- **Remote - SSH** — edit Jetson files in-place (`~/Edge`, `~/module`) from your laptop.
- **VS Code** — install the Microsoft **Remote - SSH** extension.
- **Cursor** — Remote - SSH is built in.

Full walkthrough: [Getting Started with Jetson — Remote Development](https://www.jetson-ai-lab.com/tutorials/getting-started-with-jetson/)

---

## `remote_sshfs`

**Purpose** — Mount the Jetson root on the host via **sshfs** (file browser access without Remote SSH in the editor).

**Run**

```bash
./host/remote_sshfs                         # prompt for absolute mount path
./host/remote_sshfs /home/you/jetson_root   # mount directly
./host/remote_sshfs --umount /home/you/jetson_root
```

**Raw commands**

```bash
mkdir -p ~/jetson_root
sshfs -o ConnectTimeout=5 edge@$BOARD_IP:/ ~/jetson_root
fusermount -u ~/jetson_root
```

Requires **sshfs** + FUSE on Linux/macOS/WSL. On **Windows (Git Bash)** install [WinFsp](https://github.com/winfsp/winfsp) + [SSHFS-Win](https://github.com/winfsp/sshfs-win) (`winget install WinFsp.WinFsp` then `winget install SSHFS-Win.SSHFS-Win`). Same LAN/USB route pick as `remote_ssh`.

---

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
./host/remote_ssh
```

On Jetson: `cd ~/Edge && ./connect_wifi && ./default_setup`

Teardown: `./host/reject default_setup` or `source ./host/uninstall`

View inject log anytime: `cat catalog.list` (also printed by `inject` and `reject --all`).

---

## When things break

| Problem | Fix |
|---------|-----|
| Board unreachable | Cable, IP in `config.sh`, try USB |
| Host key changed | Re-run — script runs `ssh-keygen -R` |
| SSH permission denied | Password when prompted, or `ssh-copy-id edge@<ip>` |
| Catalog empty after manual copy | Run `./host/inject <name>` |
| Spawns missing | Add `# spawn` to edge script header, re-inject |
