#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TARGET_DIR=
if [[ -d /home/pi/sbitx ]]; then
  DEFAULT_TARGET_DIR=/home/pi/sbitx
elif [[ -d /home/pi/sbit ]]; then
  DEFAULT_TARGET_DIR=/home/pi/sbit
else
  DEFAULT_TARGET_DIR=/home/pi/sbitx
fi

TARGET_DIR="${1:-${TARGET_DIR:-${DEFAULT_TARGET_DIR}}}"
BACKUP_DIR="${TARGET_DIR}.runtime-backup.$(date +%Y%m%d-%H%M%S)"
BINARY_NAME="sbitx"
LIB_DIR_NAME="lib"
WRAPPER_NAME="run-sbitx.sh"

require_file() {
  local path="$1"
  [[ -f "${path}" ]] || {
    echo "Required file is missing: ${path}" >&2
    exit 1
  }
}

copy_if_exists() {
  local source_path="$1"
  local dest_path="$2"
  local mode="$3"
  if [[ -e "${source_path}" ]]; then
    install -D -m "${mode}" "${source_path}" "${dest_path}"
  fi
}

if [[ ! -d "${TARGET_DIR}" ]]; then
  echo "Target install directory does not exist: ${TARGET_DIR}" >&2
  exit 1
fi

if pgrep -x sbitx >/dev/null 2>&1; then
  echo "The sbitx application is still running." >&2
  echo "Stop it on the target Pi, then rerun this installer." >&2
  exit 1
fi

require_file "${SCRIPT_DIR}/${BINARY_NAME}"
if [[ ! -d "${SCRIPT_DIR}/${LIB_DIR_NAME}" ]]; then
  echo "Runtime library directory is missing: ${SCRIPT_DIR}/${LIB_DIR_NAME}" >&2
  exit 1
fi

mkdir -p "${BACKUP_DIR}"
copy_if_exists "${TARGET_DIR}/${BINARY_NAME}" "${BACKUP_DIR}/${BINARY_NAME}" 0755
copy_if_exists "${TARGET_DIR}/${WRAPPER_NAME}" "${BACKUP_DIR}/${WRAPPER_NAME}" 0755
if [[ -d "${TARGET_DIR}/${LIB_DIR_NAME}" ]]; then
  cp -a "${TARGET_DIR}/${LIB_DIR_NAME}" "${BACKUP_DIR}/${LIB_DIR_NAME}"
fi

install -D -m 0755 "${SCRIPT_DIR}/${BINARY_NAME}" "${TARGET_DIR}/${BINARY_NAME}"
mkdir -p "${TARGET_DIR}/${LIB_DIR_NAME}"
find "${TARGET_DIR}/${LIB_DIR_NAME}" -mindepth 1 -maxdepth 1 -type f -delete
while IFS= read -r lib_file; do
  install -D -m 0644 "${lib_file}" "${TARGET_DIR}/${LIB_DIR_NAME}/$(basename "${lib_file}")"
done < <(find "${SCRIPT_DIR}/${LIB_DIR_NAME}" -mindepth 1 -maxdepth 1 -type f | sort)

cat > "${TARGET_DIR}/${WRAPPER_NAME}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
LOADER="$(find "${LIB_DIR}" -maxdepth 1 -type f \( -name 'ld-linux*.so*' -o -name 'ld-*.so*' \) | head -n 1)"

if [[ -n "${LOADER}" ]]; then
  exec "${LOADER}" --library-path "${LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}" "${SCRIPT_DIR}/sbitx" "$@"
fi

export LD_LIBRARY_PATH="${LIB_DIR}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
exec "${SCRIPT_DIR}/sbitx" "$@"
EOF

chmod 0755 "${TARGET_DIR}/${WRAPPER_NAME}"
chmod 0755 "${TARGET_DIR}/${BINARY_NAME}"

if [[ "${TARGET_DIR}" == "/home/pi/sbit" && ! -e /home/pi/sbitx ]]; then
  ln -s /home/pi/sbit /home/pi/sbitx
  echo "Created /home/pi/sbitx -> /home/pi/sbit for runtime compatibility"
fi

echo "Installed runtime bundle into ${TARGET_DIR}"
echo "Backup saved in ${BACKUP_DIR}"
echo
echo "Run the bundled binary with:"
echo "  ${TARGET_DIR}/${WRAPPER_NAME}"
