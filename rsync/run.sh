#!/usr/bin/env bash
# Orchelium rsync plugin — run.sh
# Receives a JSON blob as $1 containing all input values.
# Outputs structured JSON on stdout so results are available in workflow context.

# NOTE: Do NOT use set -e here. rsync returns non-zero on failure, and we need
# to capture that exit code explicitly rather than aborting the script.
set -uo pipefail

# Redirect all stderr to stdout so nothing is silently lost
# (the agent only captures stdout to the logfile)
exec 2>&1

# INPUT_JSON is injected by the Orchelium hub as a variable at the top of this
# script, so it should already be set. Fall back to $1 for direct invocation.
INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

# Parse inputs using python3 (available on most systems) or jq
parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" <<< "$INPUT_JSON" 2>/dev/null \
    || echo ""
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
OPTIONS=$(parse_field options)
SSH_KEY=$(parse_field ssh_key)
BANDWIDTH=$(parse_field bandwidth_limit)

# Apply defaults for optional fields
: "${OPERATION:=sync}"
: "${OPTIONS:=-avz}"

if [ -z "$SOURCE" ] || [ -z "$DESTINATION" ]; then
  echo '{"success":false,"error":"source and destination are required"}'
  exit 1
fi

# Validate source path exists (for local paths)
if [[ "$SOURCE" != *:* ]] && [ ! -e "$SOURCE" ]; then
  echo "[rsync] ERROR: source path does not exist: $SOURCE"
  echo '{"success":false,"error":"source path does not exist"}'
  exit 1
fi

# Build rsync command
RSYNC_ARGS=()

if [ "$OPERATION" = "check" ]; then
  # Check mode: dry-run with checksum comparison — no files are transferred
  RSYNC_ARGS+=("--dry-run" "--checksum" "-av" "--itemize-changes")
else
  # Sync mode: apply user-supplied options
  if [ -n "$OPTIONS" ]; then
    # shellcheck disable=SC2086
    read -ra OPT_ARRAY <<< "$OPTIONS"
    RSYNC_ARGS+=("${OPT_ARRAY[@]}")
  fi
  # Bandwidth limit (sync only)
  if [ -n "$BANDWIDTH" ] && [ "$BANDWIDTH" != "0" ] && [ "$BANDWIDTH" != "" ]; then
    RSYNC_ARGS+=("--bwlimit=${BANDWIDTH}")
  fi
fi

# SSH key (applies to both modes)
if [ -n "$SSH_KEY" ]; then
  RSYNC_ARGS+=("-e" "ssh -i ${SSH_KEY} -o StrictHostKeyChecking=no")
fi

RSYNC_ARGS+=("$SOURCE" "$DESTINATION")

echo "[rsync] Running: rsync ${RSYNC_ARGS[*]}"

START_TS=$(date +%s)
run_and_capture rsync "${RSYNC_ARGS[@]}"
EXIT_CODE=$CAPTURED_EXIT_CODE
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

RSYNC_OUTPUT=$CAPTURED_OUTPUT

if [ "$OPERATION" = "check" ]; then
  # Itemized output lines starting with >f or .f indicate checksum mismatches
  MISMATCHES=$(echo "$RSYNC_OUTPUT" | grep -cE '^[<>c.][fd]' 2>/dev/null || true)
  : "${MISMATCHES:=0}"
  if [ "$MISMATCHES" -eq 0 ] && [ "$EXIT_CODE" -eq 0 ]; then
    echo "[rsync] CHECK PASSED — source and destination match"
  else
    echo "[rsync] CHECK FOUND ${MISMATCHES} mismatch(es)"
    # Non-zero mismatches is a check failure even if rsync itself exited 0
    [ "$MISMATCHES" -gt 0 ] && EXIT_CODE=1
  fi
  FILES_TRANSFERRED=0
else
  # Count transferred files from rsync verbose output
  FILES_TRANSFERRED=$(echo "$RSYNC_OUTPUT" | grep -c '^[^/]*/' 2>/dev/null || true)
  : "${FILES_TRANSFERRED:=0}"
  MISMATCHES=0
  if [ "$EXIT_CODE" -ne 0 ]; then
    echo "[rsync] FAILED with exit code $EXIT_CODE"
  fi
fi

# Emit structured JSON summary (detected automatically by workflow context)
python3 - <<PYEOF
import json, sys
result = {
    "success":          $EXIT_CODE == 0,
    "exitCode":         $EXIT_CODE,
    "operation":        "$OPERATION",
    "source":           "$SOURCE",
    "destination":      "$DESTINATION",
    "durationSeconds":  $DURATION,
    "filesTransferred": $FILES_TRANSFERRED,
}
if "$OPERATION" == "check":
    result["mismatches"] = $MISMATCHES
    result["matched"]    = $MISMATCHES == 0
else:
    result["options"] = "$OPTIONS"
print(json.dumps(result))
PYEOF

exit $EXIT_CODE
