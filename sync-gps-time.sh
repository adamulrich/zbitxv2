#!/bin/sh
set -eu

usage() {
  cat <<'EOF'
Usage: sync-gps-time.sh [--host HOST] [--port PORT] [--samples N]

Reads UTC time from gpsd via gpspipe, sets the Linux system clock, and, if the
sBitx app is running, asks it to copy the current system UTC time into the
DS3231 RTC with the rtcsync command.

Options:
  --host HOST     sBitx remote host for rtcsync (default: 127.0.0.1)
  --port PORT     sBitx remote port for rtcsync (default: 8081)
  --samples N     gpspipe sample count to scan for a valid TPV time (default: 60)
  --help          Show this help text

Requirements:
  - Run as root (or via sudo) so the script can set system time
  - gpsd and gpspipe installed and gpsd providing TPV messages with time
  - python3 installed
EOF
}

HOST=127.0.0.1
PORT=8081
SAMPLES=60

while [ $# -gt 0 ]; do
  case "$1" in
    --host)
      HOST="$2"
      shift 2
      ;;
    --port)
      PORT="$2"
      shift 2
      ;;
    --samples)
      SAMPLES="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this script with sudo so it can set the system clock." >&2
  exit 1
fi

if ! command -v gpspipe >/dev/null 2>&1; then
  echo "gpspipe was not found. Install gpsd and gpsd-clients first." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 was not found." >&2
  exit 1
fi

GPS_TIME=$(
  gpspipe -w -n "$SAMPLES" 2>/dev/null | python3 -c '
import json
import sys

for line in sys.stdin:
    line = line.strip()
    if not line:
        continue
    try:
        obj = json.loads(line)
    except Exception:
        continue
    if obj.get("class") != "TPV":
        continue
    mode = obj.get("mode", 0)
    ts = obj.get("time")
    if mode >= 2 and isinstance(ts, str) and ts:
        print(ts)
        raise SystemExit(0)

raise SystemExit(1)
'
) || {
  echo "Unable to get a valid GPS UTC timestamp from gpsd." >&2
  exit 1
}

echo "Setting system UTC time from GPS: $GPS_TIME"
date -u -s "$GPS_TIME" >/dev/null

if python3 - "$HOST" "$PORT" <<'PY'
import socket
import sys

host = sys.argv[1]
port = int(sys.argv[2])
try:
    with socket.create_connection((host, port), timeout=2) as sock:
        sock.sendall(b"rtcsync\n")
except OSError:
    raise SystemExit(1)
PY
then
  echo "Requested DS3231/app time sync via sBitx remote command."
else
  echo "System time was updated, but sBitx was not reachable on $HOST:$PORT for rtcsync." >&2
  echo "Start sBitx and then run the radio command: \\rtcsync" >&2
fi
