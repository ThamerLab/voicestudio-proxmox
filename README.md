<div align="center">

# 🎙️ VoiceStudio for Proxmox

**Community Proxmox LXC installer for the official VoiceStudio Docker image**

![Proxmox](https://img.shields.io/badge/Proxmox-VE%208%2F9-E57000) ![CPU](https://img.shields.io/badge/Mode-CPU%20first-0D9488) ![Status](https://img.shields.io/badge/Status-Unverified%20beta-orange)

</div>

> [!IMPORTANT]
> **Unverified community beta.** Installer has not yet run on a real Proxmox machine. This is not affiliated with debpalash, VoiceStudio, or Proxmox. Review `install.sh` before running it. It creates a **new unprivileged Debian 12 LXC** with nesting and keyctl for Docker-in-LXC, which **weakens isolation compared with a native LXC application**. If isolation and reliability are your priorities, use a dedicated Linux VM instead.

## What it installs

- New unprivileged Debian 12 x86_64 Proxmox LXC; refuses to overwrite an existing CT ID.
- Docker from Debian repositories inside the LXC.
- Official `ghcr.io/debpalash/voicestudio:stable` Docker image (CPU mode).
- Persistent `voicestudio-data` Docker volume for model weights, projects, and data.
- Strong generated VoiceStudio API key; opt-out of optional usage analytics.
- Restart policy for Docker container and Proxmox CT on boot.
- Access to official VoiceStudio browser UI over TCP port 3900 (configurable on CT).

## Requirements

| Resource | Installer default |
|---|---|
| Host | Proxmox VE 8/9, x86-64 |
| CT OS | Debian 12 template |
| vCPU | 4 |
| RAM | 12 GiB (8 GiB minimum enforced) |
| Disk | 40 GiB (30 GiB minimum enforced) |
| Networking | vmbr0 + DHCP |
| Service port | 3900 inside LXC |

CPU inference and the first model download can be slow. Memory and disk requirements grow significantly with additional models. **NVIDIA/AMD GPU passthrough is deliberately not automated** by this installer; use a Linux VM or separately maintained GPU guide.

## Install

On a Proxmox **host shell** as root:

```bash
git clone https://github.com/ThamerLab/voicestudio-proxmox.git
cd voicestudio-proxmox
less install.sh   # Review before use
bash install.sh
```

Choose container ID, name, storage, RAM, cores, disk, port, and bridge. Confirm by typing `CREATE`. The script refuses to overwrite a pre-existing CT.

The terminal prints the newly generated API key only on completion. Store it in a password manager. The key is also stored inside the CT at `/etc/voicestudio/voicestudio.env` with restrictive permissions.

Open `http://CONTAINER_IP:3900` **only on a trusted LAN/VPN** and provide the API key through the VoiceStudio UI when prompted. The upstream Docker UI is the official VoiceStudio interface; there is no duplicate custom UI.

## Management

```bash
pct status CTID
pct exec CTID -- docker ps
pct exec CTID -- docker logs -f voicestudio
pct exec CTID -- docker restart voicestudio
pct exec CTID -- cat /etc/voicestudio/voicestudio.env
```

Update procedure (backup/snapshot **first**):

```bash
pct exec CTID -- docker pull ghcr.io/debpalash/voicestudio:stable
# Recreate container with the SAME env file, data volume and port.
# Do not remove voicestudio-data.
```

Updates are not automatic; keeping the exact image version pinned is preferable in critical use. Take and test **Proxmox backups** and keep API keys confidential.

## Security

- LXC+Docker nesting is not the same isolation as a proper VM; do not expose Docker socket to untrusted users.
- The installer binds VoiceStudio to the CT's network interface for LAN access. **Never port-forward TCP 3900 to the public Internet.** Use HTTPS reverse proxy with access control or a private VPN for remote use.
- API keys over plain HTTP can be intercepted. Use HTTPS/WSS for untrusted networks.
- Audio and voice samples can be sensitive; only use voice cloning with consent.
- Model licenses are independent from VoiceStudio's AGPL-3.0; check each model's terms before commercial use.
- Installation failure does not delete the created CT automatically; inspect it before retrying with a new ID.

## Upstream and credits

- [VoiceStudio](https://github.com/debpalash/VoiceStudio) — official application
- [Official Docker documentation](https://github.com/debpalash/VoiceStudio/blob/main/docs/install/docker.md)
- [KittenTTS Proxmox](https://github.com/ThamerLab/kittentts-proxmox) — separate, lighter alternative

This repository only automates a community deployment of the official image; it does not modify or redistribute the VoiceStudio source.
