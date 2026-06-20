# Host scripts

Host-side entry points for the Jetson workflow. Run from `scripts/host/` on your laptop.

**Post-flash edition** — `inject`, `reject`, `remote_ssh`, `remote_sshfs`: reach the live board over SSH (LAN `BOARD_IP` first, USB `BOARD_IP_USB` fallback). Board IP and user come from `config.sh`.

**Pre-flash edition** — `local_bsp`: stay on the host and set up a BSP customization workspace (`Linux_for_Tegra`) under `jetson-image/` before flashing. No SSH to the Jetson required.

Implementation is in `function/` (sourced library, not executed on its own).

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
BSP_WORKSPACE="${BSP_WORKSPACE:-}"   # empty → <repo>/jetson-image
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
         scripts/host/local_bsp scripts/host/pull_rootfs scripts/host/remote_ssh \
         scripts/host/remote_sshfs scripts/host/uninstall scripts/host/install
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

## `local_bsp`

**Purpose** — Pre-flash edition. Install [NVIDIA jetson-bsp-skills](https://github.com/NVIDIA-AI-IOT/jetson-bsp-skills) on the host and initialize a BSP workspace at **`jetson-image/`** in this repo. Opposite of `remote_ssh`: work stays on your workstation while you customize the platform image (`Linux_for_Tegra`) before flashing.

Where [jetson-device-skills](../edge/README.md#device_skill) run on the live Jetson, BSP skills run on the host. Pick a target, prepare the BSP image and sources, apply customizations (pinmux, USB, PCIe, camera, nvpmodel, etc.), then build, flash, and validate — guided by agent skills in the workspace.

| Stage | What it covers |
|-------|----------------|
| **Setup** | Select target, download/register BSP inputs, extract image, init sources |
| **Customize** | Pinmux, USB, PCIe, UPHY, clocks, fan, nvpmodel, camera, MGBE, memory |
| **Build** | Rebuild DTBs, kernel modules when kernel-side sources change |
| **Deploy** | Promote changes into the BSP image, flash, validate |

**Run**

```bash
cd scripts/host
./local_bsp
./local_bsp --workspace ~/my_bsp
./local_bsp --force
```

**Raw commands**

```bash
git clone --depth 1 https://github.com/NVIDIA-AI-IOT/jetson-bsp-skills.git ~/jetson_bsp_skills
mkdir -p <repo>/jetson-image
bash ~/jetson_bsp_skills/setup.sh --workspace <repo>/jetson-image
```

Re-run: `git -C ~/jetson_bsp_skills pull --ff-only`, then `setup.sh` again. Use `--force` to rebuild an existing workspace `.claude/`.

**Paths**

- Clone: `~/jetson_bsp_skills`
- Workspace: `<repo>/jetson-image` (override with `BSP_WORKSPACE` in `config.sh`)

Does not touch the Jetson. Does not flash — it only prepares the host workspace.

**Next step** — Open the workspace in Claude Code and ask to set up the BSP customization workspace. Entry point: `/jetson-quick-start`. NVIDIA's `setup.sh` targets Claude Code (writes `/.claude/` in the workspace).

Reference: [jetson-bsp-skills](https://github.com/NVIDIA-AI-IOT/jetson-bsp-skills)

---

## `pull_rootfs`

**Purpose** — Seed `jetson-image/Image/Linux_for_Tegra/rootfs/` from the **live Jetson** instead of downloading NVIDIA's sample rootfs. Use when the board already runs the release you want and you will edit from that snapshot.

**What this copies vs what it does not**

| Copied from device | Still from NVIDIA (if you re-flash) |
|---|---|
| Full rootfs (`/etc`, `/usr`, `/home`, packages, your configs) | `flash.sh`, bootloader pack, host flash layout |
| L4T version → `target-platform/*.yaml` `bsp_image.version` | Kernel **source** tree (`public_sources`) for DTB edits |

**Run**

```bash
cd scripts/host
./pull_rootfs          # default: quiesce + two tar passes
./pull_rootfs -y
./pull_rootfs --fast   # single pass only (faster, less consistent)
```

**Raw idea**

```bash
ssh edge@$BOARD_IP 'sudo tar -cpf - --one-file-system --exclude=/proc ... -C / .' \
  | tar -xpf - -C jetson-image/Image/Linux_for_Tegra/rootfs/
```

Requires Jetson **sudo** (password once). Large transfer — allow several minutes.

On **Windows Git Bash**, symlinks are dereferenced automatically; `/usr/src` (kernel headers) is skipped. For a full native Linux rootfs tree, run `./pull_rootfs` from **WSL2** instead.

After pull, open **`jetson-image/`** in Cursor and customize. For kernel/DTB work run `/jetson-init-source`; to re-flash run `/jetson-download-bsp` once for host-side `Linux_for_Tegra` tools.

---

## `remote_ssh`

**Purpose** — Post-flash edition. Open a shell on the Jetson.

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

**Pre-flash** (host only — customize platform image before flashing):

```bash
cd scripts/host
./local_bsp
# open jetson-image/ in Claude Code → /jetson-quick-start
```

**Post-flash** (live Jetson over SSH):

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
