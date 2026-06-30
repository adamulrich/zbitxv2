#!/usr/bin/env bash
set -euo pipefail

if [[ "${EUID}" -ne 0 ]]; then
  echo "Run this script with sudo so it can install packages." >&2
  exit 1
fi

export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y gpsd gpsd-clients chrony

echo
echo "Installed: gpsd gpsd-clients chrony"
echo "Check GPS data with: gpspipe -w -n 10"
echo "Sync time with: sudo ./sync-gps-time.sh"
