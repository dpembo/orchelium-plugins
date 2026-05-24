#!/usr/bin/env bash
# Orchelium systemd plugin — run.sh
# Receives a JSON blob as $1 containing all input values.

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

parse_bool() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); v=d.get('$field',False); print('true' if v is True or str(v).lower()=='true' else 'false')" <<< "$INPUT_JSON" 2>/dev/null \
    || echo "false"
}

run_and_capture() {
  local log_file
  log_file=$(mktemp)

  if command -v stdbuf >/dev/null 2>&1; then
    stdbuf -oL -eL "$@" | tee "$log_file"
  else
    "$@" | tee "$log_file"
  fi

  CAPTURED_EXIT_CODE=${PIPESTATUS[0]}
  CAPTURED_OUTPUT=$(cat "$log_file")
  rm -f "$log_file"
}

OPERATION=$(parse_field operation)
SERVICE=$(parse_field service)
USER_MODE=$(parse_bool user_mode)
NO_BLOCK=$(parse_bool no_block)

: "${OPERATION:=status}"

if [ -z "$SERVICE" ]; then
  echo '{"success":false,"error":"service name is required"}'
  exit 1
fi

# Check systemctl is available
if ! command -v systemctl &>/dev/null; then
  echo '{"success":false,"error":"systemctl not found — systemd is not available on this host"}'
  exit 1
fi

# Build systemctl args
SYSTEMCTL_ARGS=()
[ "$USER_MODE" = "true" ] && SYSTEMCTL_ARGS+=("--user")
[ "$NO_BLOCK" = "true" ] && SYSTEMCTL_ARGS+=("--no-block")

echo "[systemd] Running: systemctl ${SYSTEMCTL_ARGS[*]:-} $OPERATION $SERVICE"

run_and_capture systemctl "${SYSTEMCTL_ARGS[@]:-}" "$OPERATION" "$SERVICE"
OUTPUT=$CAPTURED_OUTPUT
EXIT_CODE=$CAPTURED_EXIT_CODE

# For status/is-active, capture the active state
ACTIVE_STATE=""
if [ "$OPERATION" = "status" ] || [ "$OPERATION" = "is-active" ]; then
  ACTIVE_STATE=$(systemctl "${SYSTEMCTL_ARGS[@]:-}" is-active "$SERVICE" 2>/dev/null || true)
fi

# Emit structured JSON summary
python3 - <<PYEOF
import json
result = {
    "success":   $EXIT_CODE == 0,
    "exitCode":  $EXIT_CODE,
    "operation": "$OPERATION",
    "service":   "$SERVICE",
    "userMode":  "$USER_MODE" == "true",
}
if "$ACTIVE_STATE":
    result["activeState"] = "$ACTIVE_STATE"
print(json.dumps(result))
PYEOF

exit $EXIT_CODE
