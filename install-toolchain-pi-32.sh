#!/usr/bin/env bash
set -euo pipefail

SCRIPT_NAME="$(basename "$0")"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WIRINGPI_REPO="https://github.com/WiringPi/WiringPi.git"

usage() {
  cat <<'EOF'
Usage:
  ./install-toolchain.sh [--runtime] [--skip-wiringpi] [--check]

Options:
  --runtime         Also install common runtime packages from install.txt
                    (`ntp` and `ntpstat`).
  --skip-wiringpi   Do not install wiringPi.
  --check           Print a short toolchain summary after installation.
  -h, --help        Show this help message.

This script targets Debian-based Linux systems, especially Raspberry Pi OS.
EOF
}

info() {
  printf '[INFO] %s\n' "$*"
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

die() {
  printf '[ERROR] %s\n' "$*" >&2
  exit 1
}

require_linux() {
  [[ "$(uname -s)" == "Linux" ]] || die "This installer only supports Linux."
  command -v apt-get >/dev/null 2>&1 || die "This installer requires apt-get."
}

maybe_fix_legacy_buster_apt() {
  if [[ ! -r /etc/os-release ]]; then
    return
  fi

  # Raspberry Pi OS Buster images often need their apt sources rewritten to
  # the legacy mirrors before apt-get update will succeed.
  if grep -qi '^VERSION_CODENAME=buster$' /etc/os-release; then
    info "Detected Buster. Repairing apt sources to use Raspberry Pi legacy mirrors."
    run_as_root bash "${SCRIPT_DIR}/fix-legacy-apt.sh"
  fi
}

is_raspberry_pi() {
  [[ -r /proc/device-tree/model ]] && grep -qi "Raspberry Pi" /proc/device-tree/model
}

have_wiringpi() {
  command -v gpio >/dev/null 2>&1 || ldconfig -p 2>/dev/null | grep -q "libwiringPi"
}

run_as_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    "$@"
  elif command -v sudo >/dev/null 2>&1; then
    sudo "$@"
  else
    die "This step needs root. Re-run as root or install sudo."
  fi
}

ensure_root_access() {
  if [[ "${EUID}" -eq 0 ]]; then
    return
  fi

  command -v sudo >/dev/null 2>&1 || die "This script needs root privileges and sudo is not installed."
  info "Requesting sudo access for package installation"
  sudo -v || die "Unable to obtain sudo access."
}

apt_install() {
  run_as_root apt-get install -y "$@"
}

apt_package_available() {
  apt-cache show "$1" >/dev/null 2>&1
}

apt_install_optional() {
  local pkg
  for pkg in "$@"; do
    if apt_package_available "${pkg}"; then
      apt_install "${pkg}"
    else
      warn "Package '${pkg}' is not available in this distribution; skipping."
    fi
  done
}

install_wiringpi() {
  if [[ "${SKIP_WIRINGPI}" == "1" ]]; then
    info "Skipping wiringPi by request."
    return
  fi

  if have_wiringpi; then
    info "wiringPi already appears to be installed."
    return
  fi

  if ! is_raspberry_pi; then
    warn "Not running on a Raspberry Pi. Skipping wiringPi installation."
    warn "Use --skip-wiringpi to silence this warning on non-Pi systems."
    return
  fi

  local temp_dir repo_dir deb_file
  temp_dir="$(mktemp -d)"
  repo_dir="${temp_dir}/WiringPi"
  trap 'rm -rf "${temp_dir}"' RETURN

  info "Cloning WiringPi from ${WIRINGPI_REPO}"
  git clone --depth 1 "${WIRINGPI_REPO}" "${repo_dir}"

  info "Building WiringPi Debian package"
  (
    cd "${repo_dir}"
    ./build debian
  )

  deb_file="$(find "${repo_dir}/debian-template" -maxdepth 1 -type f -iname 'wiringpi*.deb' | head -n 1)"
  [[ -n "${deb_file}" ]] || die "Could not find built wiringPi .deb package."

  info "Installing $(basename "${deb_file}")"
  run_as_root dpkg -i "${deb_file}" || run_as_root apt-get install -f -y

  if ! have_wiringpi; then
    die "wiringPi install finished, but the tools/libraries still are not visible."
  fi

  info "wiringPi installation complete."
}

print_checks() {
  printf '\nToolchain summary:\n'
  printf '  gcc:        %s\n' "$(command -v gcc || echo missing)"
  printf '  make:       %s\n' "$(command -v make || echo missing)"
  printf '  pkg-config: %s\n' "$(command -v pkg-config || echo missing)"
  printf '  sqlite3:    %s\n' "$(command -v sqlite3 || echo missing)"
  printf '  gpio:       %s\n' "$(command -v gpio || echo missing)"

  if pkg-config --exists gtk+-3.0 2>/dev/null; then
    printf '  gtk+-3.0:   ok\n'
  else
    printf '  gtk+-3.0:   missing\n'
  fi

  if ldconfig -p 2>/dev/null | grep -q "libfftw3f"; then
    printf '  libfftw3f:  ok\n'
  else
    printf '  libfftw3f:  missing\n'
  fi
}

SKIP_WIRINGPI=0
INSTALL_RUNTIME=0
RUN_CHECKS=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      INSTALL_RUNTIME=1
      shift
      ;;
    --skip-wiringpi)
      SKIP_WIRINGPI=1
      shift
      ;;
    --check)
      RUN_CHECKS=1
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

require_linux
ensure_root_access
maybe_fix_legacy_buster_apt

BUILD_PACKAGES=(
  build-essential
  gcc
  g++
  make
  pkg-config
  git
  wget
  curl
  ca-certificates
  sqlite3
  libasound2-dev
  libgtk-3-dev
  libsqlite3-dev
  libfftw3-dev
  libfftw3-bin
  libncurses-dev
)

RUNTIME_PACKAGES=(
  ntp
  ntpstat
)

info "Updating apt package lists"
run_as_root apt-get update

info "Installing build packages"
apt_install "${BUILD_PACKAGES[@]}"

if [[ "${INSTALL_RUNTIME}" == "1" ]]; then
  info "Installing runtime helper packages"
  apt_install_optional "${RUNTIME_PACKAGES[@]}"
fi

install_wiringpi

if [[ "${RUN_CHECKS}" == "1" ]]; then
  print_checks
fi

info "Toolchain installation complete."
info "Next steps:"
info "  1. Run ./install-toolchain.sh --runtime --check on the Pi if you also want ntp tools."
info "  2. Build the app with: make"
info "  3. Review DEPLOY.md for snd-aloop, /boot/config.txt, and AP setup."
