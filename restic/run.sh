#!/usr/bin/env bash
# Orchelium restic plugin — run.sh
# INPUT_JSON is injected by the Orchelium hub as a variable prepended to this script.
# Falls back to $1 for direct / manual invocation.

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

OPERATION=$(parse_field operation)
REPO=$(parse_field repo)
PASSWORD_FILE=$(parse_field password_file)
PATHS=$(parse_field paths)
TAGS=$(parse_field tags)
EXCLUDE=$(parse_field exclude)
FORGET_POLICY=$(parse_field forget_policy)
SNAPSHOT_ID=$(parse_field snapshot_id)
RESTORE_TARGET=$(parse_field restore_target)
EXTRA_FLAGS=$(parse_field extra_flags)

# Apply defaults
: "${OPERATION:=backup}"
: "${SNAPSHOT_ID:=latest}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$REPO" ]; then
  echo '{"success":false,"error":"repo is required"}'
  exit 1
fi

if ! command -v restic &>/dev/null; then
  echo '[restic] ERROR: restic is not installed on this agent'
  echo '{"success":false,"error":"restic not found in PATH"}'
  exit 1
fi

# ── Build common flags ──────────────────────────────────────────────────────────

RESTIC_ARGS=("--repo" "$REPO" "--json")

if [ -n "$PASSWORD_FILE" ]; then
  if [ ! -f "$PASSWORD_FILE" ]; then
    echo "[restic] ERROR: password file does not exist: $PASSWORD_FILE"
    echo '{"success":false,"error":"password file not found"}'
    exit 1
  fi
  RESTIC_ARGS+=("--password-file" "$PASSWORD_FILE")
elif [ -z "${RESTIC_PASSWORD:-}" ]; then
  echo "[restic] WARNING: no password_file set and RESTIC_PASSWORD is not in environment"
fi

# ── Build operation-specific flags ─────────────────────────────────────────────

case "$OPERATION" in
  backup)
    if [ -z "$PATHS" ]; then
      echo '{"success":false,"error":"paths is required for backup operation"}'
      exit 1
    fi
    # Split paths and tags on spaces
    read -ra PATH_ARRAY  <<< "$PATHS"
    RESTIC_ARGS+=("backup")
    if [ -n "$TAGS" ]; then
      read -ra TAG_ARRAY <<< "$TAGS"
      for tag in "${TAG_ARRAY[@]}"; do
        RESTIC_ARGS+=("--tag" "$tag")
      done
    fi
    if [ -n "$EXCLUDE" ]; then
      read -ra EXCL_ARRAY <<< "$EXCLUDE"
      for excl in "${EXCL_ARRAY[@]}"; do
        RESTIC_ARGS+=("--exclude" "$excl")
      done
    fi
    RESTIC_ARGS+=("${PATH_ARRAY[@]}")
    ;;

  forget)
    RESTIC_ARGS+=("forget")
    if [ -n "$FORGET_POLICY" ]; then
      read -ra POLICY_ARRAY <<< "$FORGET_POLICY"
      RESTIC_ARGS+=("${POLICY_ARRAY[@]}")
    fi
    ;;

  check)
    RESTIC_ARGS+=("check")
    ;;

  snapshots)
    RESTIC_ARGS+=("snapshots")
    ;;

  restore)
    if [ -z "$RESTORE_TARGET" ]; then
      echo '{"success":false,"error":"restore_target is required for restore operation"}'
      exit 1
    fi
    RESTIC_ARGS+=("restore" "$SNAPSHOT_ID" "--target" "$RESTORE_TARGET")
    ;;

  *)
    echo "[restic] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

if [ -n "$EXTRA_FLAGS" ]; then
  read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
  RESTIC_ARGS+=("${EXTRA_ARRAY[@]}")
fi

# ── Execute ─────────────────────────────────────────────────────────────────────

echo "[restic] Running: restic ${RESTIC_ARGS[*]}"

START_TS=$(date +%s)
RESTIC_OUTPUT=$(restic "${RESTIC_ARGS[@]}" 2>&1)
EXIT_CODE=$?
DURATION=$(( $(date +%s) - START_TS ))

echo "$RESTIC_OUTPUT"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[restic] FAILED with exit code $EXIT_CODE"
fi

# ── Parse JSON output for workflow context ──────────────────────────────────────
# restic --json emits a JSON object on the last line for most operations.
# Extract snapshot_id and files_new from backup output if available.

python3 - <<PYEOF
import json, sys

raw = """$RESTIC_OUTPUT"""
operation = "$OPERATION"
exit_code = $EXIT_CODE
duration  = $DURATION

result = {
    "success":       exit_code == 0,
    "exitCode":      exit_code,
    "operation":     operation,
    "durationSeconds": duration,
}

# Try to parse the last JSON line from restic --json output
for line in reversed(raw.strip().splitlines()):
    line = line.strip()
    if line.startswith('{'):
        try:
            data = json.loads(line)
            # backup summary
            if operation == "backup":
                result["snapshotId"]      = data.get("snapshot_id", "")
                result["filesNew"]        = data.get("files_new", 0)
                result["filesChanged"]    = data.get("files_changed", 0)
                result["filesUnmodified"] = data.get("files_unmodified", 0)
                result["dataAdded"]       = data.get("data_added", 0)
                result["totalDuration"]   = data.get("total_duration", duration)
            elif operation == "snapshots":
                result["snapshotCount"] = len(data) if isinstance(data, list) else 1
        except (json.JSONDecodeError, TypeError):
            pass
        break

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
