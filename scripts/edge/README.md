# Edge scripts

## Spawns

Declared in each script header as `# spawn KIND ITEM`. The host reads them at inject and writes `> KIND ITEM` rows to `catalog.list`. They record what a script *might* install so reject knows what to remove. If the script was never run, reject skips anything not on the device.

```bash
# spawn apt python3-pip
# spawn pip jetson-stats
```

| Kind | Teardown (on reject) |
|------|----------------------|
| `apt` | `dpkg -s` check → `apt-get remove` |
| `pip` | `pip3 show` check → `pip3 uninstall` |
| `git` | `rm -rf` clone path if present |
| `dir` | `rm -rf` path if present |

| Script | Spawns |
|--------|--------|
| `connect_wifi` | none |
| `default_setup` | `apt python3-pip`, `pip jetson-stats` |

---

Run on the Jetson after the host injects them to `~/Edge`. Inject only copies the file — nothing runs until you SSH in and execute it.

Details: [host/README.md](../host/README.md) · Overview: [../README.md](../README.md)

---

## `connect_wifi`

**Purpose** — Join Wi-Fi from the Jetson and enable SSH on boot so the host can reach it over LAN instead of USB.

**Run**

```bash
cd ~/Edge
./connect_wifi                  # scan, pick network, enter Wi-Fi password
./connect_wifi list             # scan and print networks
./connect_wifi "SSID" "pass"    # connect directly
```

**Raw commands**

Scan (`list` or before interactive pick):

```bash
nmcli device wifi rescan
sleep 2
nmcli -t -f SSID,SIGNAL device wifi list   # deduped/sorted in script via awk
nmcli device wifi list                      # list mode only
```

Connect (all modes that join a network):

```bash
sudo -v                                     # if sudo not cached
nmcli radio wifi on
sudo nmcli device wifi connect "SSID" password "pass"
hostname -I | awk '{print $1}'              # print IP after success
sudo systemctl enable ssh
sudo systemctl start ssh
```

**Spawns** — none.

**Reject removes** — `rm -f ~/Edge/connect_wifi` (from host via SSH). No packages or services undone.

---

## `default_setup`

**Purpose** — Install pip and jetson-stats (jtop) on a fresh Jetson.

**Run**

```bash
cd ~/Edge
./default_setup
sudo jtop    # after install
```

**Raw commands**

```bash
sudo -v
sudo apt install -y python3-pip
sudo -H pip3 install -U jetson-stats
```

**Spawns** — `apt python3-pip`, `pip jetson-stats` (see top).

**Reject removes** (from host, per catalog — only if present on device)

```bash
dpkg -s python3-pip && sudo apt-get remove -y --purge python3-pip
pip3 show jetson-stats && sudo pip3 uninstall -y jetson-stats
rm -f ~/Edge/default_setup
```

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

Edge scripts use interactive sudo — no password file on the Jetson from this repo. Use `./host/inject` (not manual `scp`) if catalog and reject should stay in sync.
