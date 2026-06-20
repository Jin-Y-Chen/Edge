# Edge scripts

## Spawns

Declared in each script header as `# spawn KIND ITEM`. The host reads them at inject and writes `> KIND ITEM` rows to `catalog.list`.

**Why spawns exist.** Inject only copies a script to `~/Edge`; it does not run it. When a script eventually runs, it may install packages with `apt` or `pip`, clone repos, or create directories on the Jetson. The host cannot observe that automatically. Spawn lines declare those side effects up front so `reject` and `uninstall` can tear them down later: not only the script file, but also the system changes the script was designed to make. Inject logs spawns even if the script was never executed. On reject, anything not present on the device is skipped.

**Declare only non-default installs.** JetPack already ships tools like `git`. Do not add `# spawn apt git` — reject must not remove base image packages. Scripts may still run `apt install git` as a fallback if missing.

```bash
# spawn apt python3-pip
# spawn pip jetson-stats
# spawn git jetson_stats ~/jetson_stats
```

| Kind | Teardown on reject |
|------|-------------------|
| `pip` | stop/disable service → `pip3 uninstall` → **pip cache purge** + `systemctl daemon-reload` |
| `git` | `sudo rm -rf` clone path if present |
| `dir` | `sudo rm -rf` path if present |
| `apt` | `dpkg -s` check → `apt-get remove` → **`apt autoremove`** + **`apt autoclean`** when the script has any `apt` spawn |

Reject runs spawns in order: **pip → git/dir → apt → post-cleanup**.

| Script | Spawns |
|--------|--------|
| `connect_wifi` | none |
| `default_setup` | `apt python3-pip`, `pip jetson-stats`, `git jetson_stats ~/jetson_stats` |
| `device_skill` | `git jetson_device_skills ~/jetson_device_skills` |
| `max_power` | none |

---

Run on the Jetson after the host injects them to `~/Edge`. Inject only copies the file. Nothing runs until you SSH in and execute it.

Details: [host/README.md](../host/README.md) · Overview: [../README.md](../README.md)

**Why these scripts.** After flash, the Jetson is usually reached over USB at `192.168.55.x`. That works for first boot but is awkward for daily use. `connect_wifi` moves SSH to LAN Wi-Fi and keeps SSH enabled on boot. `default_setup` installs jtop. `device_skill` installs NVIDIA Jetson agent skills so Cursor knows how to work on this board. `max_power` sets max `nvpmodel`, `jetson_clocks`, fan cool profile, and optional headless boot before heavy workloads.

---

## `connect_wifi`

**Purpose.** Join Wi-Fi from the Jetson and enable SSH on boot so the host can reach it over LAN instead of USB.

USB gadget networking works out of the box after flash, but the cable ties the board to the host and the IP differs from normal LAN. Wi-Fi gives a stable address on the home network. Set `BOARD_IP` in `config.sh`. Enabling SSH on boot lets the host connect after a power cycle without a monitor.

**Run**

```bash
cd ~/Edge
./connect_wifi                  # scan, pick network, enter Wi-Fi password
./connect_wifi list             # scan and print networks
./connect_wifi "SSID" "pass"    # connect directly
```

**Raw commands**

Scan for `list` or before an interactive pick:

```bash
nmcli device wifi rescan
sleep 2
nmcli -t -f SSID,SIGNAL device wifi list   # deduped/sorted in script via awk
nmcli device wifi list                      # list mode only
```

Connect in all modes that join a network:

```bash
sudo -v                                     # if sudo not cached
nmcli radio wifi on
sudo nmcli device wifi connect "SSID" password "pass"
hostname -I | awk '{print $1}'              # print IP after success
sudo systemctl enable ssh
sudo systemctl start ssh
```

**Spawns.** None.

**Reject removes.** `rm -f ~/Edge/connect_wifi` from the host via SSH. No packages or services are undone.

---

## `default_setup`

**Purpose.** Install pip and jtop on a fresh Jetson.

**Run**

```bash
cd ~/Edge
./default_setup
sudo jtop    # after install
```

**Raw commands**

```bash
sudo -v
sudo apt install -y python3-pip git
sudo pip3 uninstall -y UNKNOWN jetson-stats 2>/dev/null || true
sudo -H pip3 install -U pip setuptools wheel
sudo rm -rf ~/jetson_stats
git clone --depth 1 https://github.com/rbonghi/jetson_stats.git ~/jetson_stats
sudo -H pip3 install -U ~/jetson_stats
sudo systemctl restart jtop.service
```

**jtop.** [jetson-stats](https://github.com/rbonghi/jetson_stats) is a terminal monitor for Jetson, similar to `htop` for the board. Run `sudo jtop` after install. One UI covers hardware and Jetpack info, live CPU, GPU, RAM, temperature, fan, and runtime controls. Use arrow keys or `1` through `8` to switch pages. Layout varies slightly by Jetson model. Also useful: `jetson_release -v`, `sudo jtop --health`.

| Page | What it shows |
|------|----------------|
| **ALL** | Board summary: Jetpack/L4T, **NVP mode** via `nvpmodel`, clocks, CPU/GPU/RAM bars |
| **CPU** | Per-core load and frequency |
| **GPU** | GPU load, frequency, optional iGPU details |
| **MEM** | RAM, swap, cached memory, and GPU/shared memory where available |
| **MISC** | Fan speed, temperatures, `jetson_clocks` status |
| **ENG** | Hardware **engine** usage. Each block shows **OFF** or ON and clock in MHz. Summary row `[JP]` lists DLA, PVA, NVDEC, NVENC, NVJPG, SE, APE, and others. |
| **CTRL** | Toggle **`jetson_clocks`**, pick **NVP mode** such as **MAXN_SUPER**, and set **fan speed** or fan profile. Requires `sudo jtop`. |
| **INFO** | Hardware ID, P-number, Jetpack detection, installed libs such as CUDA, OpenCV, TensorRT |

**Spawns**

- `apt python3-pip`. Jetson images ship without a reliable pip install path. This apt package provides `pip3` for PyPI tools.
- `pip jetson-stats`. Installs `jtop` and `jtop.service` from the clone. Newer than PyPI and needed for recent L4T such as 36.5.0. jtop is the usual way to read board state in one terminal: `nvpmodel` power mode, `jetson_clocks` status, CPU/GPU load, RAM, swap, temperature, and fan. Install before changing performance settings or loading models. Most Jetson AI Lab flows assume it is available.
- `git jetson_stats ~/jetson_stats`. Shallow clone of [rbonghi/jetson_stats](https://github.com/rbonghi/jetson_stats). pip installs from this directory, not `pip install git+https://...`.

`git` is not spawned — it is part of JetPack; the script uses it but reject does not remove it.

Logged at inject. See the Spawns section at the top. Reject removes each item only if it is present on the device.

**jtop references.** [docs](https://rnext.it/jetson_stats) · [TUI guide](https://rnext.it/jetson_stats/jtop/jtop.html) · [Python API](https://rnext.it/jetson_stats/jtop.html) · [troubleshooting](https://rnext.it/jetson_stats/troubleshooting.html) · [GitHub](https://github.com/rbonghi/jetson_stats) · [NVIDIA](https://developer.nvidia.com/embedded/community/jetson-projects/jetson_stats)

**Reject removes** from the host per catalog, only if present on the device:

```bash
pip3 show jetson-stats && sudo systemctl stop jtop.service && sudo systemctl disable jtop.service
pip3 show jetson-stats && sudo pip3 uninstall -y jetson-stats
sudo pip3 cache purge 2>/dev/null || sudo rm -rf ~/.cache/pip /root/.cache/pip
sudo systemctl daemon-reload
sudo rm -rf ~/jetson_stats
dpkg -s python3-pip && sudo apt-get remove -y --purge python3-pip
sudo apt-get autoremove -y && sudo apt-get autoclean -y
rm -f ~/Edge/default_setup
```

---

## `device_skill`

**Purpose.** Install [NVIDIA jetson-device-skills](https://github.com/NVIDIA-AI-IOT/jetson-device-skills) for Cursor (and optionally Claude/Codex) — jtop for the agent, not you.

It is the Jetson service manual. Without it, chat drifts to generic Linux advice. Skills cover diagnostics, memory tuning, headless setup, LLM serving, benchmarks, and package selection. This script only installs them; when you ask in chat, the agent runs scripts like `snapshot.sh` against live hardware.

Connection via **Remote SSH** on Cursor allow the agents to read the skills from `~/.cursor/skills/` like other project folder on the board. 

**Run on the Jetson.** The skills are distributed through the [jetson-device-skills](https://github.com/NVIDIA-AI-IOT/jetson-device-skills) repository and install into the Jetson user's `~/.cursor/skills/`.

```bash
cd ~/Edge
./device_skill              # cursor (default)
./device_skill all          # claude + codex + cursor
./device_skill claude,cursor
```

**Raw commands**

```bash
sudo apt install -y git
git clone --depth 1 https://github.com/NVIDIA-AI-IOT/jetson-device-skills.git ~/jetson_device_skills
bash ~/jetson_device_skills/install.sh --targets cursor
# restart Cursor agent session
```

**Spawns.**

- `git jetson_device_skills ~/jetson_device_skills`. Shallow clone; `install.sh` symlinks skills into agent config dirs.

**Reject removes.** Clone at `~/jetson_device_skills` and the script file. Symlinks in `~/.cursor/skills/jetson-*` (and other agent paths) are not removed — delete manually or re-run `./device_skill`.

Reference: [Getting Started with Jetson — AI-Assisted Workflows](https://www.jetson-ai-lab.com/tutorials/getting-started-with-jetson/)

---

## `max_power`

**Purpose.** One-shot max performance from the shell.                                

**Run**

```bash
cd ~/Edge
./max_power                              # maxn_super + jetson_clocks + fan cool (1)
./max_power --mode 25w                   # balanced NVP (no jetson_clocks)
./max_power --mode 15w --fan 0           # low power + quiet fan
./max_power --mode maxn_super --fan 2 --fanspeed 80   # manual fan 80%
./max_power --gui 0                      # also disable desktop (reboot after)
./max_power --gui 1                      # restore desktop (reboot after)
./max_power status
```

| Option | Values |
|--------|--------|
| `--mode` | `15w`, `25w`, `maxn_super` (default) |
| `--gui` | `0` headless, `1` desktop |
| `--fan` | `0` quiet, `1` cool (default), `2` manual |
| `--fanspeed` | `0`–`100` percent, use with `--fan 2` |

**Raw commands**

```bash
sudo -v
sudo nvpmodel -q
sudo nvpmodel -m 2                       # index from --mode name; check nvpmodel -q
sudo jetson_clocks
sudo sed -i 's/^\([[:space:]]*FAN_DEFAULT_PROFILE\).*/\1 cool/' /etc/nvfancontrol.conf
sudo systemctl restart nvfancontrol      # --fan 0 or 1
sudo systemctl stop nvfancontrol         # --fan 2 manual
echo 204 | sudo tee /sys/devices/platform/pwm-fan/hwmon/hwmon*/pwm1   # --fanspeed 80
sudo systemctl set-default multi-user.target   # --gui 0
sudo systemctl set-default graphical.target    # --gui 1
sudo reboot                              # after --gui change
```

**Max Super Mode** `nvpmodel` sets power and performance caps defined by NVIDIA. Mode names and watt limits depend on your module. List modes on your board:

```bash
sudo nvpmodel -q          # current mode + index
cat /etc/nvpmodel.conf    # all mode names: MAXN, 15W, 25W, …
```

Typical **Jetson Orin Nano** modes. Indexes can differ; always check `nvpmodel -q`:

| Mode name | Role |
|-----------|------|
| **MAXN** / **MAXN_SUPER** | Max performance for inference, vision, and Docker models |
| **25W** and mid modes | Balanced power |
| **15W** and low modes | Cooler, lower draw for idle or battery-like setups |

**Max Power with jtop CTRL.** 

The **Max Super Mode**, **Jetson Clock**, and **Fan Speed** can also be freely configure with **`sudo jtop`** in **CTRL**. Use **NVP modes** to select **MAXN_SUPER**. Use **jetson_clocks** to enable or disable run clock. Use **PWMFAN** to adjust the speed of the fan. Jtop CTRL help you experiment or dial back without shell commands. Disable/Enable GUI can only be done via shell scripts. 

**Spawns.** None. Runtime settings only. Reject removes the script file.

**Reject removes.** `rm -f ~/Edge/max_power`

---

## Adding a script

1. Create `scripts/edge/<name>` with `# spawn` lines for anything reject should track.
2. Inject: `./host/inject <name>`
3. Run on Jetson: `cd ~/Edge && ./<name>`

Header template:

```bash
#!/usr/bin/env bash
# what this does
# spawn apt package-name
# spawn pip pypi-name
set -euo pipefail
```

Edge scripts use interactive sudo. This repo does not store a password file on the Jetson. Use `./host/inject` instead of manual `scp` so catalog and reject stay in sync.
