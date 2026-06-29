#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DEFAULT_TARGET_DIR=
if [[ -d /home/pi/sbitx ]]; then
  DEFAULT_TARGET_DIR=/home/pi/sbitx
elif [[ -d /home/pi/sbit ]]; then
  DEFAULT_TARGET_DIR=/home/pi/sbit
else
  DEFAULT_TARGET_DIR=/home/pi/sbitx
fi

TARGET_DIR="${1:-${TARGET_DIR:-$DEFAULT_TARGET_DIR}}"
BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d-%H%M%S)"
FILES_TO_INSTALL=(
  "Makefile"
  "build"
  "modem_ft8.c"
  "sbitx_gtk.c"
  "ft8_lib/ft8/pack.c"
  "ft8_lib/ft8/unpack.c"
  "ft8_lib/ft8/unpack.h"
  "web/index.html"
  "web/indexv2.html"
  "data/default_settings.ini"
)

install_mode_for() {
  case "$1" in
    build)
      printf '0755\n'
      ;;
    *)
      printf '0644\n'
      ;;
  esac
}

copy_if_exists() {
  local source_path="$1"
  local dest_path="$2"
  local mode="$3"

  if [[ -e "$source_path" ]]; then
    install -D -m "$mode" "$source_path" "$dest_path"
  fi
}

if [[ ! -d "$TARGET_DIR" ]]; then
  echo "Target install directory does not exist: $TARGET_DIR" >&2
  echo "Pass the real target path as the first argument if needed." >&2
  echo "Expected a checked-out source tree, usually /home/pi/sbitx or /home/pi/sbit." >&2
  exit 1
fi

if pgrep -x sbitx >/dev/null 2>&1; then
  echo "The sbitx application is still running." >&2
  echo "Stop it on the Zero 2 W, then rerun this installer." >&2
  exit 1
fi

for relative_path in "${FILES_TO_INSTALL[@]}"; do
  if [[ ! -f "$SCRIPT_DIR/$relative_path" ]]; then
    echo "Update bundle is incomplete. Missing: $SCRIPT_DIR/$relative_path" >&2
    exit 1
  fi
done

mkdir -p "$BACKUP_DIR"
for relative_path in "${FILES_TO_INSTALL[@]}"; do
  mode="$(install_mode_for "$relative_path")"
  copy_if_exists "$TARGET_DIR/$relative_path" "$BACKUP_DIR/$relative_path" "$mode"
  install -D -m "$mode" "$SCRIPT_DIR/$relative_path" "$TARGET_DIR/$relative_path"
done

(
  cd "$TARGET_DIR"
  make clean
  make
)

if [[ "$TARGET_DIR" == "/home/pi/sbit" && ! -e /home/pi/sbitx ]]; then
  ln -s /home/pi/sbit /home/pi/sbitx
  echo "Created /home/pi/sbitx -> /home/pi/sbit for runtime compatibility"
fi

echo "Installed source update into $TARGET_DIR"
echo "Backup saved in $BACKUP_DIR"
echo "Rebuild completed on the Zero 2 W"
