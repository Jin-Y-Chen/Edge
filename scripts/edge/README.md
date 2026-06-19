# Edge scripts

These scripts run **on the Jetson**, not on your host. The host copies them to `~/Edge` (or `EDGE_ROOT`) via `./host/inject <name>`. You SSH in and run them manually when needed.

## Layout

```
scripts/edge/
  connect_wifi      # Wi-Fi setup + enable SSH on boot
  default_setup     # pip + jetson-stats (jtop)
  README.md         # this file
```

After inject, on the Jetson:

```
~/Edge/
  connect_wifi
  default_setup
```

## Architecture

```
  HOST                              EDGE (Jetson)
  ────                              ─────────────

  edge/connect_wifi  ──inject──►    ~/Edge/connect_wifi
  edge/default_setup ──inject──►    ~/Edge/default_setup
        │
        │  # spawn lines (header)          │  you run:
        ▼                                ▼
  catalog.list                     sudo, apt, pip, nmcli, …
  (logged at inject)               (only when you execute)
```

- **Inject** = deliver script + record metadata on the host.
- **Run** = your choice on the Jetson; nothing runs automatically.
- **Reject** = host reads `catalog.list` and undoes declared spawns + removes the script file.

## Spawn declarations

Side effects that a script *may* cause are declared in the script **header** as comments. At inject time, the host writes them to `catalog.list` under that script’s entry.

```bash
# spawn KIND ITEM
# spawn KIND ITEM EXTRA
```

Supported kinds (used on reject/uninstall):

| Kind | Catalog example | Teardown behavior |
|------|-----------------|-------------------|
| `apt` | `> apt python3-pip` | `apt-get remove` if package installed |
| `pip` | `> pip jetson-stats` | `pip3 uninstall` if package installed |
| `git` | `> git REPO /path/to/clone` | `rm -rf` clone path if present |
| `dir` | `> dir NAME /path/to/dir` | `rm -rf` path if present |

Injecting records spawns even if you never run the script. Reject skips removal for anything not actually on the device.

### Example: `default_setup`

```bash
#!/usr/bin/env bash
# Jetson first-run setup: install jtop.
# spawn apt python3-pip
# spawn pip jetson-stats
set -euo pipefail
```

After `./host/inject default_setup`, `catalog.list` contains:

```
dd/mm/yy--HH:MM-- | default_setup  ~/Edge
> apt  python3-pip
> pip  jetson-stats
```

## Scripts

### `connect_wifi`

Connect the Jetson to Wi-Fi and enable SSH on boot after a successful connect.

**Run on Jetson** (after inject):

```bash
cd ~/Edge
./connect_wifi
```

Interactive — scans networks, you pick one, enter Wi-Fi password:

```bash
./connect_wifi
```

List networks only:

```bash
./connect_wifi list
```

Direct SSID + password:

```bash
./connect_wifi "MyNetwork" "MyWifiPassword"
```

**What it does**

1. Prompts for sudo if needed.
2. Connects via `nmcli`.
3. Enables and starts `ssh` systemd service on boot.
4. Prints LAN IP and reminds you to use `./host/remote_ssh` from the host.

No `# spawn` lines — reject only removes the script file, not system packages.

---

### `default_setup`

Install `python3-pip` and `jetson-stats` (jtop).

**Run on Jetson** (after inject):

```bash
cd ~/Edge
./default_setup
```

Then:

```bash
sudo jtop
```

**Declared spawns** (logged at inject, torn down on reject if installed):

```bash
# spawn apt python3-pip
# spawn pip jetson-stats
```

## Full example session

### Host

```bash
cd scripts
./host/install
nano config.sh

./host/inject connect_wifi
./host/inject default_setup
./host/catalog list
./host/remote_ssh
```

Expected catalog:

```
dd/mm/yy--HH:MM-- | connect_wifi  ~/Edge
dd/mm/yy--HH:MM-- | default_setup  ~/Edge
> apt  python3-pip
> pip  jetson-stats
```

### Jetson (over USB or existing SSH)

```bash
cd ~/Edge
./connect_wifi
# pick network, enter Wi-Fi password

./default_setup
# enter sudo password when prompted

sudo jtop
```

### Host again (after Wi-Fi — LAN SSH)

```bash
./host/remote_ssh
```

### Remove setup from edge (keep connect_wifi)

```bash
./host/reject default_setup
```

Removes `~/Edge/default_setup`, attempts to remove `python3-pip` and `jetson-stats` if present, updates catalog.

## Adding a new edge script

1. Create `scripts/edge/my_script` (executable bash).
2. Add `# spawn` lines in the header for any apt/pip/git/dir side effects.
3. Inject from host:

```bash
./host/inject my_script
```

4. SSH to Jetson and run:

```bash
cd ~/Edge
./my_script
```

Template:

```bash
#!/usr/bin/env bash
# Short description.
# spawn apt some-package
# spawn pip some-pypi-name
set -euo pipefail

[[ "${1:-}" == "-h" || "${1:-}" == "--help" ]] && {
  echo "Usage: ./my_script"
  exit 0
}

sudo -n true 2>/dev/null || { echo "Sudo password required."; sudo -v; }

# your commands here
```

## Notes

- Edge scripts use **interactive sudo** — there is no password file on the Jetson from this repo.
- `# spawn` lines are comments only on the Jetson; the host reads them at inject time.
- Do not rely on manual `scp` to `~/Edge` if you want catalog/reject to work — always use `./host/inject`.
