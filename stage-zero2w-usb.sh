#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
STAGING_DIR_NAME="${STAGING_DIR_NAME:-zbitxv2-zero2w-update}"
FILES_TO_STAGE=(
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
  "install-on-zero2w.sh"
  "install-zero2w-deps.sh"
  "sync-gps-time.sh"
)

find_usb_mount() {
  local media_root="/media/${USER}"
  local matches=()
  local entry

  if [[ ! -d "$media_root" ]]; then
    echo "Expected removable media under $media_root, but that directory does not exist." >&2
    return 1
  fi

  while IFS= read -r entry; do
    matches+=("$entry")
  done < <(find "$media_root" -mindepth 1 -maxdepth 1 -type d | sort)

  if (( ${#matches[@]} == 1 )); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  if (( ${#matches[@]} == 0 )); then
    echo "No mounted USB volume found under $media_root." >&2
  else
    echo "Multiple mounted volumes found under $media_root. Pass the mount path explicitly." >&2
    printf '  %s\n' "${matches[@]}" >&2
  fi

  return 1
}

require_file() {
  local path="$1"

  if [[ ! -f "$path" ]]; then
    echo "Required file is missing: $path" >&2
    exit 1
  fi
}

install_mode_for() {
  case "$1" in
    build|install-on-zero2w.sh|install-zero2w-deps.sh|sync-gps-time.sh)
      printf '0755\n'
      ;;
    *)
      printf '0644\n'
      ;;
  esac
}

USB_ROOT="${1:-${USB_MOUNT:-}}"
if [[ -z "$USB_ROOT" ]]; then
  USB_ROOT="$(find_usb_mount)"
fi

if [[ ! -d "$USB_ROOT" ]]; then
  echo "USB mount path does not exist: $USB_ROOT" >&2
  exit 1
fi

if [[ ! -w "$USB_ROOT" ]]; then
  echo "USB mount is not writable: $USB_ROOT" >&2
  echo "Remount the drive read-write, then rerun this script." >&2
  exit 1
fi

BUNDLE_DIR="$USB_ROOT/$STAGING_DIR_NAME"
mkdir -p "$BUNDLE_DIR"

for relative_path in "${FILES_TO_STAGE[@]}"; do
  source_path="$REPO_ROOT/$relative_path"
  dest_path="$BUNDLE_DIR/$relative_path"
  require_file "$source_path"
  install -D -m "$(install_mode_for "$relative_path")" "$source_path" "$dest_path"
done

echo "Staged Zero 2 W source-update bundle at:"
echo "  $BUNDLE_DIR"
echo
echo "On the Zero 2 W, stop the running app first, then run:"
echo "  cd \"$BUNDLE_DIR\""
echo "  sudo ./install-zero2w-deps.sh"
echo "  ./install-on-zero2w.sh"
