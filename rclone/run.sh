#!/usr/bin/env bash
# Orchelium rclone plugin — run.sh
# INPUT_JSON is injected by the Orchelium hub as a variable prepended to this
# script. Falls back to $1 for direct / manual invocation.

set -uo pipefail

# Merge stderr into stdout — the agent only captures stdout to the logfile.
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

# ── Parse inputs ────────────────────────────────────────────────────────────────

parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" \
    <<< "$INPUT_JSON" 2>/dev/null || echo ""
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
SOURCE=$(parse_field source)
DESTINATION=$(parse_field destination)
CONFIG_FILE=$(parse_field config_file)
TRANSFERS=$(parse_field transfers)
CHECKERS=$(parse_field checkers)
BWLIMIT=$(parse_field bwlimit)
INCLUDE=$(parse_field include)
EXCLUDE=$(parse_field exclude)
FILTER_FILE=$(parse_field filter_file)
CHECKSUM=$(parse_field checksum)
DRY_RUN=$(parse_field dry_run)
LOG_LEVEL=$(parse_field log_level)
EXTRA_FLAGS=$(parse_field extra_flags)

# Apply defaults
: "${OPERATION:=sync}"
: "${LOG_LEVEL:=NOTICE}"
: "${CHECKSUM:=no}"
: "${DRY_RUN:=no}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$SOURCE" ]; then
  echo '{"success":false,"error":"source is required"}'
  exit 1
fi

case "$OPERATION" in
  sync|copy|move|check)
    if [ -z "$DESTINATION" ]; then
      echo "{\"success\":false,\"error\":\"destination is required for ${OPERATION} operation\"}"
      exit 1
    fi
    ;;
esac

if ! command -v rclone &>/dev/null; then
  echo "[rclone] ERROR: rclone is not installed on this agent"
  echo '{"success":false,"error":"rclone not found in PATH"}'
  exit 1
fi

# Validate config file if specified
if [ -n "$CONFIG_FILE" ] && [ ! -f "$CONFIG_FILE" ]; then
  echo "[rclone] ERROR: config file does not exist: $CONFIG_FILE"
  echo '{"success":false,"error":"rclone config file not found"}'
  exit 1
fi

# ── Build common flags ──────────────────────────────────────────────────────────

RCLONE_ARGS=()

# Config file
[ -n "$CONFIG_FILE" ] && RCLONE_ARGS+=("--config" "$CONFIG_FILE")

# Log level + stats in machine-readable JSON
RCLONE_ARGS+=("--log-level" "$LOG_LEVEL")
RCLONE_ARGS+=("--use-json-log")
RCLONE_ARGS+=("--stats" "0")          # summary stats at end only
RCLONE_ARGS+=("--stats-one-line")

# Performance
[ -n "$TRANSFERS" ] && [ "$TRANSFERS" != "0" ] && RCLONE_ARGS+=("--transfers" "$TRANSFERS")
[ -n "$CHECKERS"  ] && [ "$CHECKERS"  != "0" ] && RCLONE_ARGS+=("--checkers"  "$CHECKERS")

# Bandwidth
[ -n "$BWLIMIT" ] && RCLONE_ARGS+=("--bwlimit" "$BWLIMIT")

# Checksum
[ "$CHECKSUM" = "yes" ] && RCLONE_ARGS+=("--checksum")

# Dry run
[ "$DRY_RUN" = "yes" ] && RCLONE_ARGS+=("--dry-run")

# Include/exclude patterns
if [ -n "$INCLUDE" ]; then
  read -ra INC_ARRAY <<< "$INCLUDE"
  for pat in "${INC_ARRAY[@]}"; do
    RCLONE_ARGS+=("--include" "$pat")
  done
fi

if [ -n "$EXCLUDE" ]; then
  read -ra EXCL_ARRAY <<< "$EXCLUDE"
  for pat in "${EXCL_ARRAY[@]}"; do
    RCLONE_ARGS+=("--exclude" "$pat")
  done
fi

[ -n "$FILTER_FILE" ] && RCLONE_ARGS+=("--filter-from" "$FILTER_FILE")

# Extra flags
[ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; RCLONE_ARGS+=("${EF[@]}"); }

# ── Build operation-specific args ──────────────────────────────────────────────

case "$OPERATION" in
  sync|copy|move|check)
    OP_ARGS=("$OPERATION" "$SOURCE" "$DESTINATION")
    ;;
  ls)
    OP_ARGS=("lsjson" "$SOURCE")
    ;;
  delete)
    OP_ARGS=("delete" "$SOURCE")
    ;;
  purge)
    OP_ARGS=("purge" "$SOURCE")
    ;;
  *)
    echo "[rclone] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

# ── Execute ─────────────────────────────────────────────────────────────────────

echo "[rclone] Running: rclone ${OP_ARGS[*]} ${RCLONE_ARGS[*]}"

START_TS=$(date +%s)
run_and_capture rclone "${OP_ARGS[@]}" "${RCLONE_ARGS[@]}"
EXIT_CODE=$CAPTURED_EXIT_CODE
DURATION=$(( $(date +%s) - START_TS ))

RCLONE_OUTPUT=$CAPTURED_OUTPUT

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[rclone] FAILED with exit code $EXIT_CODE (see https://rclone.org/docs/#exit-code)"
fi

# ── Parse JSON log output for workflow context ──────────────────────────────────
# rclone --use-json-log emits JSON log lines; the final stats line contains
# the transfer summary. For ls/lsjson the full output is a JSON array.

python3 - <<PYEOF
import json, sys, re

raw        = """$RCLONE_OUTPUT"""
operation  = "$OPERATION"
exit_code  = $EXIT_CODE
duration   = $DURATION
dry_run    = "$DRY_RUN" == "yes"

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "source":          "$SOURCE",
    "destination":     "$DESTINATION",
    "durationSeconds": duration,
    "dryRun":          dry_run,
}

# rclone exit code meanings
EXIT_MEANINGS = {
    0: "success",
    1: "syntax or usage error",
    2: "error not retried",
    3: "directory not found",
    4: "file not found",
    5: "temporary error (was retried)",
    6: "less serious errors",
    7: "fatal error",
    8: "transfer limit exceeded",
    9: "success but no files transferred",
}
result["exitMeaning"] = EXIT_MEANINGS.get(exit_code, "unknown")

if operation == "ls":
    # lsjson output is a JSON array
    try:
        stripped = raw.strip()
        # Find the JSON array (may have log lines before it)
        arr_start = stripped.rfind('[')
        if arr_start >= 0:
            data = json.loads(stripped[arr_start:])
            result["fileCount"] = len(data)
            result["files"]     = [f.get("Path", "") for f in data]
    except (json.JSONDecodeError, TypeError):
        result["fileCount"] = 0
else:
    # Parse JSON log lines looking for the stats summary
    transferred = 0
    errors      = 0
    checks      = 0
    bytes_xfer  = 0
    for line in raw.splitlines():
        line = line.strip()
        if not line.startswith('{'):
            continue
        try:
            obj = json.loads(line)
            # Stats lines have "level":"info" and a "stats" key or msg contains "Transferred:"
            stats = obj.get("stats", {})
            if stats:
                transferred = stats.get("transfers",    transferred)
                errors      = stats.get("errors",       errors)
                checks      = stats.get("checks",       checks)
                bytes_xfer  = stats.get("bytes",        bytes_xfer)
        except (json.JSONDecodeError, TypeError):
            continue

    result["filesTransferred"] = transferred
    result["errors"]           = errors
    result["checks"]           = checks
    result["bytesTransferred"] = bytes_xfer

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
