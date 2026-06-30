#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  sudo ./fix-legacy-apt.sh [--update]

Repairs Raspberry Pi OS Buster apt sources to use the legacy mirrors:
  - http://legacy.raspbian.org/raspbian
  - http://legacy.raspberrypi.org/debian

Options:
  --update    Also clear cached package lists and run apt-get update.
  -h, --help  Show this help text.
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

RUN_UPDATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      RUN_UPDATE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "Unknown option: $1"
      ;;
  esac
done

[[ "${EUID}" -eq 0 ]] || die "Run this script as root or with sudo."
command -v apt-get >/dev/null 2>&1 || die "apt-get was not found."

info "Writing Raspberry Pi OS Buster legacy apt sources"
cat > /etc/apt/sources.list <<'EOF'
deb http://legacy.raspbian.org/raspbian buster main contrib non-free rpi
EOF

mkdir -p /etc/apt/sources.list.d
cat > /etc/apt/sources.list.d/raspi.list <<'EOF'
deb http://legacy.raspberrypi.org/debian buster main
EOF

find /etc/apt/sources.list.d -maxdepth 1 -type f -name '*.list' ! -name 'raspi.list' -delete
rm -f /etc/apt/sources.list.d/*.list.save
rm -f /etc/apt/sources.list.d/*.distUpgrade
rm -f /etc/apt/sources.list.d/*.backup
rm -f /etc/apt/sources.list.d/*.disabled

cat > /etc/apt/apt.conf.d/99no-check-valid <<'EOF'
Acquire::Check-Valid-Until "false";
EOF

if [[ "${RUN_UPDATE}" == "1" ]]; then
  info "Clearing cached apt package lists"
  rm -rf /var/lib/apt/lists/*
  apt-get clean

  info "Running apt-get update against legacy mirrors"
  apt-get update
fi

info "Legacy Buster apt sources are configured."
