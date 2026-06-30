#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_BINARY="${SCRIPT_DIR}/sbitx"
STAGING_DIR_NAME="${STAGING_DIR_NAME:-sbitx-runtime-bundle}"
INSTALLER_NAME="install-binary-bundle.sh"

find_usb_mount() {
  local media_root="/media/${USER}"
  local matches=()
  local entry

  if [[ ! -d "${media_root}" ]]; then
    echo "Expected removable media under ${media_root}, but that directory does not exist." >&2
    return 1
  fi

  while IFS= read -r entry; do
    matches+=("${entry}")
  done < <(find "${media_root}" -mindepth 1 -maxdepth 1 -type d | sort)

  if (( ${#matches[@]} == 1 )); then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  if (( ${#matches[@]} == 0 )); then
    echo "No mounted USB volume found under ${media_root}." >&2
  else
    echo "Multiple mounted volumes found under ${media_root}. Pass the mount path explicitly." >&2
    printf '  %s\n' "${matches[@]}" >&2
  fi

  return 1
}

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    echo "Required file is missing: ${path}" >&2
    exit 1
  }
}

copy_dependency() {
  local source_path="$1"
  local dest_dir="$2"
  local base_name

  base_name="$(basename "${source_path}")"
  install -D -m 0644 "${source_path}" "${dest_dir}/${base_name}"
}

USB_ROOT="${1:-${USB_MOUNT:-}}"
BINARY_PATH="${2:-${BINARY_PATH:-${DEFAULT_BINARY}}}"

if [[ -z "${USB_ROOT}" ]]; then
  USB_ROOT="$(find_usb_mount)"
fi

if [[ ! -d "${USB_ROOT}" ]]; then
  echo "USB mount path does not exist: ${USB_ROOT}" >&2
  exit 1
fi

if [[ ! -w "${USB_ROOT}" ]]; then
  echo "USB mount is not writable: ${USB_ROOT}" >&2
  exit 1
fi

require_file "${BINARY_PATH}"
require_file "${SCRIPT_DIR}/${INSTALLER_NAME}"
command -v ldd >/dev/null 2>&1 || {
  echo "ldd was not found in PATH." >&2
  exit 1
}

BUNDLE_DIR="${USB_ROOT}/${STAGING_DIR_NAME}"
LIB_DIR="${BUNDLE_DIR}/lib"
mkdir -p "${LIB_DIR}"

install -D -m 0755 "${BINARY_PATH}" "${BUNDLE_DIR}/sbitx"
install -D -m 0755 "${SCRIPT_DIR}/${INSTALLER_NAME}" "${BUNDLE_DIR}/${INSTALLER_NAME}"

mapfile -t DEPENDENCIES < <(
  ldd "${BINARY_PATH}" | awk '
    $1 ~ /^linux-vdso/ { next }
    {
      for (i = 1; i <= NF; i++) {
        if ($i ~ /^\//) {
          print $i
          break
        }
      }
    }
  ' | sort -u
)

if (( ${#DEPENDENCIES[@]} == 0 )); then
  echo "No shared-library dependencies were discovered for ${BINARY_PATH}." >&2
  exit 1
fi

MANIFEST="${BUNDLE_DIR}/bundle-manifest.txt"
{
  echo "binary=$(basename "${BINARY_PATH}")"
  echo "staged_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "host=$(uname -a)"
  echo "dependencies:"
} > "${MANIFEST}"

for dep in "${DEPENDENCIES[@]}"; do
  require_file "${dep}"
  copy_dependency "${dep}" "${LIB_DIR}"
  printf '  %s\n' "${dep}" >> "${MANIFEST}"
done

echo "Staged runtime bundle at:"
echo "  ${BUNDLE_DIR}"
echo
echo "Bundle contents:"
echo "  ${BUNDLE_DIR}/sbitx"
echo "  ${BUNDLE_DIR}/lib/"
echo "  ${BUNDLE_DIR}/${INSTALLER_NAME}"
echo
echo "On the target Pi, copy the bundle local first, then run:"
echo "  cp -a \"${BUNDLE_DIR}\" ~/"
echo "  cd ~/${STAGING_DIR_NAME}"
echo "  bash ./${INSTALLER_NAME}"
