# Jetson Orin Nano Edge Computer

Personal notes, commands, and scripts from working through **[Jetson AI Lab](https://www.jetson-ai-lab.com/tutorials/)** tutorials on a Jetson Orin Nano — plus the board setup that comes before any of that.

## Overview

This repo documents **my understanding and progress** as I follow tutorials on [Jetson AI Lab](https://www.jetson-ai-lab.com/tutorials/) and other resources. It's not a replacement for those guides — it's my working notes: what I ran, what stuck, and what I'd do differently.

So far it covers the **foundation setup** (flash, SSH, performance tuning) that most Jetson AI Lab tutorials assume is already done. As I work through more tutorials, I'll add notes and scripts here and link back to the originals.

| Area | What it covers |
|------|----------------|
| **Setup** | Flash, SSH, Wi-Fi, headless access, performance tuning |
| **Tutorials** | Progress tracker with direct links to [Jetson AI Lab](https://www.jetson-ai-lab.com/tutorials/) and other sources |
| **Scripts** | Repeatable commands extracted from what actually worked |

**Tutorial progress:** [docs/tutorials.md](./docs/tutorials.md)

Everything here assumes JetPack is already on the board. If you're starting from a fresh device, see **Prerequisites**.

## Prerequisites

If you haven't flashed the appropriate **Linux (Ubuntu) JetPack** image yet, here are a couple of installation guides:

- [JetsonHacks — Orin Nano SSD install, boot, and JetPack setup](https://jetsonhacks.com/2023/05/30/jetson-orin-nano-tutorial-ssd-install-boot-and-jetpack-setup/)
- [YouTube — Jetson Orin Nano setup walkthrough](https://www.youtube.com/watch?v=f9lDqQ0QwOM&t=274s)

Both guides cover **NVMe SSD installation** — flashing JetPack to an NVMe drive from a host PC. USB and microSD are some others alternatives, but **NVMe is what I'd pick** for faster boot and more reliable storage under load. I haven't tested the other methods, but the rest of this guide should be the same software-wise. Hopefully they work regardless of how you installed JetPack.

### Hardware

- **NVIDIA Jetson Orin Nano** (Orin family)
- **NVMe SSD** — standard M.2 sizes 2280 or 2230 fit the slot, Gen 3 or above.
- **Female-to-female jumper cable (2.54mm)** — short pins 9 and 10 to enter Force Recovery Mode when flashing
- **Data-capable USB-C cable** — connects the board to a host PC for flashing and headless SSH
- **Host PC** running Ubuntu (required for SDK Manager)
- **DisplayPort monitor** (optional) — for direct on-device setup; the dev kit uses DisplayPort, not HDMI

### Software & Network

- **NVIDIA SDK Manager** — installed on the Ubuntu host PC; used to flash the correct JetPack build onto the board
- **Network** — Ethernet, Wi-Fi, or USB gadget (`192.168.55.100`)
- **SSH client** — on your host laptop (or other device); opens a remote terminal to the Jetson without a DisplayPort monitor

### Access options

Most tutorials assume you'll use a **DisplayPort monitor** for first-time setup — that gives you a direct interface on the device. If you don't have a compatible display, **headless SSH over USB-C** from a laptop is the solid alternative. For future development, a **wireless connection** via SSH will be much preferable.

## Documentation

**Board setup** — guides and scripts for the foundation most [Jetson AI Lab](https://www.jetson-ai-lab.com/tutorials/) tutorials expect:

| Guide | Script |
|-------|--------|
| [docs/remote-access.md](./docs/remote-access.md) | [`scripts/enable-ssh.sh`](./scripts/enable-ssh.sh) |
| [docs/jtop.md](./docs/jtop.md) | [`scripts/install-jtop.sh`](./scripts/install-jtop.sh) |
| [docs/power-display.md](./docs/power-display.md) | [`scripts/max-performance.sh`](./scripts/max-performance.sh), [`scripts/set-headless.sh`](./scripts/set-headless.sh) |
| [docs/sshfs.md](./docs/sshfs.md) | [`scripts/mount-jetson.sh`](./scripts/mount-jetson.sh) |

**Tutorial progress** — [docs/tutorials.md](./docs/tutorials.md) (links to Jetson AI Lab and other sources)

Edit [`scripts/config.sh`](./scripts/config.sh) to set your board IP and user before running host-side scripts.

Full index: **[docs/README.md](./docs/README.md)**

## License

Personal learning notes — not affiliated with NVIDIA or Jetson AI Lab.
