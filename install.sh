#!/usr/bin/env bash
set -Eeuo pipefail
trap 'echo "Install interrupted; inspect the new CT before retrying" >&2' ERR
[[ $EUID -eq 0 ]] || { echo "Run as root on Proxmox"; exit 1; }
for tool in pct pveam pvesm pvesh openssl; do command -v "$tool" >/dev/null || { echo "Missing $tool"; exit 1; }; done
[[ $(uname -m) == x86_64 ]] || { echo "x86-64 host required"; exit 1; }
ask() { local answer; read -r -p "$1 [$2]: " answer; printf '%s' "\${answer:-$2}"; }
ID=$(ask "New CT ID" "$(pvesh get /cluster/nextid)")
[[ $ID =~ ^[1-9][0-9]{1,5}$ ]] || exit 1
if pct status "$ID" >/dev/null 2>&1 || [[ -e "/etc/pve/lxc/$ID.conf" ]]; then
  echo "Container already exists; refusing to overwrite"; exit 1
fi
HOST=$(ask "Hostname" voicestudio)
ROOT=$(ask "Rootfs storage" local-lvm)
TSTORE=$(ask "Template storage" local)
BRIDGE=$(ask "Network bridge" vmbr0)
CORES=$(ask "CPU cores" 4)
RAM=$(ask "Memory MiB" 12288)
DISK=$(ask "Disk GiB" 40)
PORT=$(ask "Exposed TCP port" 3900)
[[ $HOST =~ ^[a-zA-Z0-9][a-zA-Z0-9-]{0,62}$ ]] || exit 1
for n in "$CORES" "$RAM" "$DISK" "$PORT"; do [[ $n =~ ^[0-9]+$ ]] || exit 1; done
(( CORES>=2 && RAM>=8192 && DISK>=30 && PORT>=1024 && PORT<=65535 )) || exit 1
pvesm status --content rootdir | awk 'NR>1 {print $1}' | grep -Fxq "$ROOT"
pvesm status --content vztmpl | awk 'NR>1 {print $1}' | grep -Fxq "$TSTORE"
TEMPLATE=$(pveam list "$TSTORE" | awk '/debian-12-standard.*amd64.*tar/ {print $1}' | sort -V | tail -1)
if [[ -z $TEMPLATE ]]; then
  pveam update
  ARCHIVE=$(pveam available --section system | awk '/debian-12-standard.*amd64/ {print $2}' | sort -V | tail -1)
  [[ -n $ARCHIVE ]] || { echo "No Debian 12 template"; exit 1; }
  pveam download "$TSTORE" "$ARCHIVE"
  TEMPLATE="$TSTORE:vztmpl/$ARCHIVE"
fi
echo "Will create NEW CT $ID, CPU $CORES, RAM $RAM MiB, disk $DISK GiB"
read -r -p "Type CREATE to confirm: " CONFIRM
[[ $CONFIRM == CREATE ]] || exit 0
KEY=$(openssl rand -hex 32)
pct create "$ID" "$TEMPLATE" --hostname "$HOST" --ostype debian --unprivileged 1 --features nesting=1,keyctl=1 --rootfs "$ROOT:$DISK" --cores "$CORES" --memory "$RAM" --swap 1024 --net0 "name=eth0,bridge=$BRIDGE,ip=dhcp" --onboot 1 --start 1
pct exec "$ID" -- bash -lc 'set -Eeuo pipefail; apt-get update; DEBIAN_FRONTEND=noninteractive apt-get install -y docker.io ca-certificates curl; systemctl enable --now docker; docker info >/dev/null'
pct exec "$ID" -- docker volume create voicestudio-data >/dev/null
pct exec "$ID" -- bash -lc "install -m 0700 -d /etc/voicestudio; printf '%s\n' 'OMNIVOICE_API_KEY=$KEY' 'OMNIVOICE_ANALYTICS_DISABLED=1' > /etc/voicestudio/voicestudio.env; chmod 0600 /etc/voicestudio/voicestudio.env"
pct exec "$ID" -- docker run -d --name voicestudio --restart unless-stopped --platform linux/amd64 --env-file /etc/voicestudio/voicestudio.env -p "$PORT:3900" -v voicestudio-data:/app/omnivoice_data ghcr.io/debpalash/voicestudio:stable >/dev/null
IP=$(pct exec "$ID" -- hostname -I | awk '{print $1}')
echo "CT: $ID | UI: http://$IP:$PORT | API key: $KEY"
echo "LAN/VPN only. Do not expose directly to the Internet."