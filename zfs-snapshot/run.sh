#!/usr/bin/env bash
# Orchelium zfs-snapshot plugin — run.sh
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
DATASET=$(parse_field dataset)
SNAPSHOT_NAME=$(parse_field snapshot_name)
RECURSIVE=$(parse_field recursive)
INCREMENTAL_FROM=$(parse_field incremental_from)
SEND_TARGET=$(parse_field send_target)
SEND_DATASET_REMOTE=$(parse_field send_dataset_remote)
CLONE_TARGET=$(parse_field clone_target)
EXTRA_FLAGS=$(parse_field extra_flags)

# Apply defaults
: "${OPERATION:=snapshot}"
: "${SNAPSHOT_NAME:=auto-%Y-%m-%dT%H:%M:%S}"
: "${RECURSIVE:=no}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$DATASET" ]; then
  echo '{"success":false,"error":"dataset is required"}'
  exit 1
fi

if ! command -v zfs &>/dev/null; then
  echo "[zfs] ERROR: zfs is not installed on this agent"
  echo '{"success":false,"error":"zfs not found in PATH"}'
  exit 1
fi

# Expand strftime placeholders in snapshot name
SNAP_SUFFIX=$(date +"$SNAPSHOT_NAME")
FULL_SNAP="${DATASET}@${SNAP_SUFFIX}"

RECURSIVE_FLAG=""
if [ "$RECURSIVE" = "yes" ]; then
  RECURSIVE_FLAG="-r"
fi

# ── Execute ─────────────────────────────────────────────────────────────────────

START_TS=$(date +%s)
EXIT_CODE=0
ZFS_OUTPUT=""

case "$OPERATION" in

  snapshot)
    ZFS_ARGS=("snapshot")
    [ -n "$RECURSIVE_FLAG" ] && ZFS_ARGS+=("$RECURSIVE_FLAG")
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; ZFS_ARGS+=("${EF[@]}"); }
    ZFS_ARGS+=("$FULL_SNAP")
    echo "[zfs] Running: zfs ${ZFS_ARGS[*]}"
    run_and_capture zfs "${ZFS_ARGS[@]}"
    ZFS_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  destroy)
    ZFS_ARGS=("destroy")
    [ -n "$RECURSIVE_FLAG" ] && ZFS_ARGS+=("$RECURSIVE_FLAG")
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; ZFS_ARGS+=("${EF[@]}"); }
    ZFS_ARGS+=("$FULL_SNAP")
    echo "[zfs] Running: zfs ${ZFS_ARGS[*]}"
    run_and_capture zfs "${ZFS_ARGS[@]}"
    ZFS_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  list)
    ZFS_ARGS=("list" "-t" "snapshot" "-o" "name,creation,used,refer" "-s" "creation")
    [ -n "$RECURSIVE_FLAG" ] && ZFS_ARGS+=("$RECURSIVE_FLAG")
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; ZFS_ARGS+=("${EF[@]}"); }
    ZFS_ARGS+=("$DATASET")
    echo "[zfs] Running: zfs ${ZFS_ARGS[*]}"
    run_and_capture zfs "${ZFS_ARGS[@]}"
    ZFS_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  send)
    if [ -z "$SEND_TARGET" ]; then
      echo '{"success":false,"error":"send_target is required for send operation"}'
      exit 1
    fi
    SEND_ARGS=("send")
    [ -n "$RECURSIVE_FLAG" ] && SEND_ARGS+=("$RECURSIVE_FLAG")
    if [ -n "$INCREMENTAL_FROM" ]; then
      SEND_ARGS+=("-i" "${DATASET}@${INCREMENTAL_FROM}")
    fi
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; SEND_ARGS+=("${EF[@]}"); }
    SEND_ARGS+=("$FULL_SNAP")

    # Determine if target is SSH (user@host) or local file
    if [[ "$SEND_TARGET" == *@* ]] && [[ "$SEND_TARGET" != /* ]]; then
      # Remote SSH receive
      RECV_DATASET="${SEND_DATASET_REMOTE:-$DATASET}"
      echo "[zfs] Running: zfs ${SEND_ARGS[*]} | ssh ${SEND_TARGET} zfs receive -F ${RECV_DATASET}"
      LOG_FILE=$(mktemp)
      if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL -eL zfs "${SEND_ARGS[@]}" | ssh "$SEND_TARGET" "zfs receive -F '$RECV_DATASET'" | tee "$LOG_FILE"
      else
        zfs "${SEND_ARGS[@]}" | ssh "$SEND_TARGET" "zfs receive -F '$RECV_DATASET'" | tee "$LOG_FILE"
      fi
      SEND_EXIT=${PIPESTATUS[0]}
      RECV_EXIT=${PIPESTATUS[1]}
      EXIT_CODE=$SEND_EXIT
      [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=$RECV_EXIT
      ZFS_OUTPUT=$(cat "$LOG_FILE")
      rm -f "$LOG_FILE"
    else
      # Local file
      echo "[zfs] Running: zfs ${SEND_ARGS[*]} > ${SEND_TARGET}"
      LOG_FILE=$(mktemp)
      if command -v stdbuf >/dev/null 2>&1; then
        stdbuf -oL -eL zfs "${SEND_ARGS[@]}" > "$SEND_TARGET" 2> >(tee "$LOG_FILE")
      else
        zfs "${SEND_ARGS[@]}" > "$SEND_TARGET" 2> >(tee "$LOG_FILE")
      fi
      EXIT_CODE=$?
      ZFS_OUTPUT=$(cat "$LOG_FILE")
      rm -f "$LOG_FILE"
    fi
    ;;

  rollback)
    ZFS_ARGS=("rollback")
    [ -n "$RECURSIVE_FLAG" ] && ZFS_ARGS+=("$RECURSIVE_FLAG")
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; ZFS_ARGS+=("${EF[@]}"); }
    ZFS_ARGS+=("$FULL_SNAP")
    echo "[zfs] Running: zfs ${ZFS_ARGS[*]}"
    run_and_capture zfs "${ZFS_ARGS[@]}"
    ZFS_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  clone)
    if [ -z "$CLONE_TARGET" ]; then
      echo '{"success":false,"error":"clone_target is required for clone operation"}'
      exit 1
    fi
    ZFS_ARGS=("clone")
    [ -n "$EXTRA_FLAGS" ] && { read -ra EF <<< "$EXTRA_FLAGS"; ZFS_ARGS+=("${EF[@]}"); }
    ZFS_ARGS+=("$FULL_SNAP" "$CLONE_TARGET")
    echo "[zfs] Running: zfs ${ZFS_ARGS[*]}"
    run_and_capture zfs "${ZFS_ARGS[@]}"
    ZFS_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  *)
    echo "[zfs] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[zfs] FAILED with exit code $EXIT_CODE"
fi

# ── Parse list output to count snapshots ───────────────────────────────────────

python3 - <<PYEOF
import json, sys

raw        = """$ZFS_OUTPUT"""
operation  = "$OPERATION"
exit_code  = $EXIT_CODE
duration   = $DURATION
dataset    = "$DATASET"
full_snap  = "$FULL_SNAP"
clone_tgt  = "$CLONE_TARGET"

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "dataset":         dataset,
    "snapshot":        full_snap,
    "durationSeconds": duration,
}

if operation == "list":
    lines = [l for l in raw.strip().splitlines() if "@" in l]
    result["snapshotCount"] = len(lines)
    result["snapshots"]     = [l.split()[0] for l in lines if l.split()]

if operation == "clone":
    result["cloneDataset"] = clone_tgt

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
