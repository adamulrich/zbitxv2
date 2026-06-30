#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$SCRIPT_DIR"
STAGING_DIR_NAME="${STAGING_DIR_NAME:-zbitxv2-zero2w-update}"
RSYNC_EXCLUDES=(
  ".git/"
  ".agents/"
  ".codex/"
  "*.o"
  "sbitx"
  "ft8_lib/libft8.a"
  "ft8_lib/test"
  "ft8_lib/a.out"
  "data/sbitx.db"
  "devshim/wiringpi_compat.o"
  "web/index.html~"
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

if ! command -v rsync >/dev/null 2>&1; then
  echo "rsync was not found. Install rsync first." >&2
  exit 1
fi

BUNDLE_DIR="$USB_ROOT/$STAGING_DIR_NAME"
mkdir -p "$BUNDLE_DIR"

RSYNC_ARGS=(-a --delete)
for pattern in "${RSYNC_EXCLUDES[@]}"; do
  RSYNC_ARGS+=(--exclude "$pattern")
done

rsync "${RSYNC_ARGS[@]}" "$REPO_ROOT/" "$BUNDLE_DIR/"

echo "Staged Zero 2 W full source tree at:"
echo "  $BUNDLE_DIR"
echo
echo "On the Zero 2 W, stop the running app first, then run:"
echo "  cd \"$BUNDLE_DIR\""
echo "  sudo ./install-zero2w-deps.sh"
echo "  ./install-on-zero2w.sh"
