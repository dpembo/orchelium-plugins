#!/usr/bin/env bash
# Orchelium wake-on-lan plugin — run.sh
# Sends a Wake-on-LAN magic packet using Python 3 (no external tools required).

set -uo pipefail
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" <<< "$INPUT_JSON" 2>/dev/null \
    || echo ""
}

parse_int() {
  local field="$1" default="$2"
  python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('$field'); print(int(v) if v not in (None,'') else $default)" <<< "$INPUT_JSON" 2>/dev/null \
    || echo "$default"
}

MAC=$(parse_field mac_address)
BROADCAST=$(parse_field broadcast_ip)
PORT=$(parse_int port 9)
COUNT=$(parse_int count 3)
WAIT=$(parse_int wait_seconds 0)

: "${BROADCAST:=255.255.255.255}"

if [ -z "$MAC" ]; then
  echo '{"success":false,"error":"mac_address is required"}'
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo '{"success":false,"error":"python3 not found — required to send magic packets"}'
  exit 1
fi

echo "[wake-on-lan] Sending $COUNT magic packet(s) to MAC $MAC via $BROADCAST:$PORT"

python3 - <<PYEOF
import socket, re, time, json, sys

mac   = "$MAC"
bcast = "$BROADCAST"
port  = int("$PORT")
count = int("$COUNT")
wait  = int("$WAIT")

# Normalise MAC: strip separators, uppercase
mac_clean = re.sub(r'[:\-]', '', mac).upper()
if len(mac_clean) != 12 or not re.fullmatch(r'[0-9A-F]{12}', mac_clean):
    print(f'[wake-on-lan] ERROR: invalid MAC address: {mac}')
    result = {"success": False, "error": f"invalid MAC address: {mac}"}
    print(json.dumps(result))
    sys.exit(1)

mac_bytes = bytes.fromhex(mac_clean)

# Magic packet: 6 bytes of 0xFF followed by the MAC repeated 16 times
magic = b'\xff' * 6 + mac_bytes * 16

sent   = 0
errors = []
with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
    sock.settimeout(5)
    for i in range(count):
        try:
            sock.sendto(magic, (bcast, port))
            sent += 1
            print(f'[wake-on-lan] Packet {i+1}/{count} sent')
        except Exception as e:
            errors.append(str(e))
            print(f'[wake-on-lan] ERROR sending packet {i+1}: {e}')

if wait > 0:
    print(f'[wake-on-lan] Waiting {wait}s...')
    time.sleep(wait)

result = {
    "success":     len(errors) == 0,
    "mac":         mac,
    "broadcast":   bcast,
    "port":        port,
    "packetsSent": sent,
    "packetCount": count,
}
if errors:
    result["errors"] = errors
print(json.dumps(result))
sys.exit(0 if not errors else 1)
PYEOF
