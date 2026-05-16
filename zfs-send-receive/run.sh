#!/usr/bin/env bash
# Orchelium zfs-send-receive plugin — run.sh
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

SOURCE_DATASET=$(parse_field source_dataset)
SOURCE_SNAPSHOT=$(parse_field source_snapshot)
INCREMENTAL_FROM=$(parse_field incremental_from)
RECURSIVE=$(parse_field recursive)
TARGET_TYPE=$(parse_field target_type)
TARGET_HOST=$(parse_field target_host)
TARGET_DATASET=$(parse_field target_dataset)
TARGET_FILE=$(parse_field target_file)
SSH_KEY=$(parse_field ssh_key)
SSH_PORT=$(parse_field ssh_port)
RAW=$(parse_field raw)
RESUME=$(parse_field resume)
RECEIVE_FLAGS=$(parse_field receive_flags)
EXTRA_SEND_FLAGS=$(parse_field extra_send_flags)

# Apply defaults
: "${SOURCE_SNAPSHOT:=latest}"
: "${RECURSIVE:=no}"
: "${TARGET_TYPE:=ssh}"
: "${RAW:=no}"
: "${RESUME:=no}"
: "${SSH_PORT:=22}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$SOURCE_DATASET" ]; then
  echo '{"success":false,"error":"source_dataset is required"}'
  exit 1
fi

if [ "$TARGET_TYPE" != "file" ] && [ -z "$TARGET_DATASET" ]; then
  echo '{"success":false,"error":"target_dataset is required for ssh and local target types"}'
  exit 1
fi

if [ "$TARGET_TYPE" = "ssh" ] && [ -z "$TARGET_HOST" ]; then
  echo '{"success":false,"error":"target_host is required when target_type is ssh"}'
  exit 1
fi

if [ "$TARGET_TYPE" = "file" ] && [ -z "$TARGET_FILE" ]; then
  echo '{"success":false,"error":"target_file is required when target_type is file"}'
  exit 1
fi

if ! command -v zfs &>/dev/null; then
  echo "[zfs-send] ERROR: zfs is not installed on this agent"
  echo '{"success":false,"error":"zfs not found in PATH"}'
  exit 1
fi

# ── Resolve 'latest' snapshot name ─────────────────────────────────────────────

resolve_latest_snapshot() {
  local dataset="$1"
  zfs list -t snapshot -o name -s creation -r "$dataset" 2>/dev/null \
    | grep "^${dataset}@" | tail -1 | cut -d@ -f2
}

if [ "$RESUME" = "yes" ]; then
  # Resume mode: ignore snapshot fields entirely
  RESOLVED_SNAP=""
  RESOLVED_INCR=""
else
  # Resolve source snapshot
  if [ "$SOURCE_SNAPSHOT" = "latest" ]; then
    RESOLVED_SNAP=$(resolve_latest_snapshot "$SOURCE_DATASET")
    if [ -z "$RESOLVED_SNAP" ]; then
      echo "[zfs-send] ERROR: no snapshots found on ${SOURCE_DATASET}"
      echo '{"success":false,"error":"no snapshots found on source dataset"}'
      exit 1
    fi
    echo "[zfs-send] Resolved latest source snapshot: ${RESOLVED_SNAP}"
  else
    RESOLVED_SNAP="$SOURCE_SNAPSHOT"
  fi

  # Resolve incremental base
  RESOLVED_INCR=""
  if [ "$INCREMENTAL_FROM" = "auto" ]; then
    # Find the most recent snapshot that exists on the destination
    if [ "$TARGET_TYPE" = "ssh" ]; then
      SSH_CMD="ssh"
      [ -n "$SSH_KEY" ] && SSH_CMD+=" -i $SSH_KEY"
      SSH_CMD+=" -p $SSH_PORT -o StrictHostKeyChecking=accept-new"
      RESOLVED_INCR=$(${SSH_CMD} "$TARGET_HOST" \
        "zfs list -t snapshot -o name -s creation -r '${TARGET_DATASET}' 2>/dev/null | grep '^${TARGET_DATASET}@' | tail -1 | cut -d@ -f2" 2>/dev/null || echo "")
    elif [ "$TARGET_TYPE" = "local" ]; then
      RESOLVED_INCR=$(zfs list -t snapshot -o name -s creation -r "$TARGET_DATASET" 2>/dev/null \
        | grep "^${TARGET_DATASET}@" | tail -1 | cut -d@ -f2 || echo "")
    fi
    if [ -n "$RESOLVED_INCR" ]; then
      echo "[zfs-send] Auto-resolved incremental base: ${RESOLVED_INCR}"
    else
      echo "[zfs-send] No common snapshot found on destination — performing full send"
    fi
  elif [ -n "$INCREMENTAL_FROM" ]; then
    RESOLVED_INCR="$INCREMENTAL_FROM"
  fi
fi

# ── Build SSH command prefix ────────────────────────────────────────────────────

build_ssh_cmd() {
  local cmd="ssh -o StrictHostKeyChecking=accept-new -p ${SSH_PORT}"
  [ -n "$SSH_KEY" ] && cmd+=" -i ${SSH_KEY}"
  cmd+=" ${TARGET_HOST}"
  echo "$cmd"
}

# ── Build zfs send arguments ────────────────────────────────────────────────────

SEND_ARGS=("send")

if [ "$RESUME" = "yes" ]; then
  # Fetch resume token from destination
  if [ "$TARGET_TYPE" = "ssh" ]; then
    SSH_CMD=$(build_ssh_cmd)
    RESUME_TOKEN=$(${SSH_CMD} "zfs get -H -o value receive_resume_token '${TARGET_DATASET}'" 2>/dev/null || echo "none")
  else
    RESUME_TOKEN=$(zfs get -H -o value receive_resume_token "$TARGET_DATASET" 2>/dev/null || echo "none")
  fi
  if [ -z "$RESUME_TOKEN" ] || [ "$RESUME_TOKEN" = "none" ] || [ "$RESUME_TOKEN" = "-" ]; then
    echo "[zfs-send] ERROR: no resume token found on destination dataset"
    echo '{"success":false,"error":"no resume token found on destination"}'
    exit 1
  fi
  echo "[zfs-send] Using resume token: ${RESUME_TOKEN:0:40}..."
  SEND_ARGS+=("-t" "$RESUME_TOKEN")
else
  [ "$RECURSIVE" = "yes" ] && SEND_ARGS+=("-R")
  [ "$RAW" = "yes" ] && SEND_ARGS+=("-w")
  if [ -n "$RESOLVED_INCR" ]; then
    SEND_ARGS+=("-i" "${SOURCE_DATASET}@${RESOLVED_INCR}")
  fi
  [ -n "$EXTRA_SEND_FLAGS" ] && { read -ra EF <<< "$EXTRA_SEND_FLAGS"; SEND_ARGS+=("${EF[@]}"); }
  SEND_ARGS+=("${SOURCE_DATASET}@${RESOLVED_SNAP}")
fi

# ── Build zfs receive arguments ─────────────────────────────────────────────────

RECV_ARGS=("receive")
[ -n "$RECEIVE_FLAGS" ] && { read -ra RF <<< "$RECEIVE_FLAGS"; RECV_ARGS+=("${RF[@]}"); }

# ── Execute ─────────────────────────────────────────────────────────────────────

START_TS=$(date +%s)
EXIT_CODE=0
BYTES_SENT=0

case "$TARGET_TYPE" in
  ssh)
    SSH_CMD=$(build_ssh_cmd)
    RECV_CMD="${SSH_CMD} zfs ${RECV_ARGS[*]} ${TARGET_DATASET}"
    echo "[zfs-send] Running: zfs ${SEND_ARGS[*]} | ${RECV_CMD}"
    zfs "${SEND_ARGS[@]}" | eval "$RECV_CMD"
    # Capture both sides of the pipe — bash sets PIPESTATUS
    PIPE_SEND=${PIPESTATUS[0]}
    PIPE_RECV=${PIPESTATUS[1]}
    [ "$PIPE_SEND" -ne 0 ] && EXIT_CODE=$PIPE_SEND || EXIT_CODE=$PIPE_RECV
    ;;

  local)
    echo "[zfs-send] Running: zfs ${SEND_ARGS[*]} | zfs ${RECV_ARGS[*]} ${TARGET_DATASET}"
    zfs "${SEND_ARGS[@]}" | zfs "${RECV_ARGS[@]}" "$TARGET_DATASET"
    PIPE_SEND=${PIPESTATUS[0]}
    PIPE_RECV=${PIPESTATUS[1]}
    [ "$PIPE_SEND" -ne 0 ] && EXIT_CODE=$PIPE_SEND || EXIT_CODE=$PIPE_RECV
    ;;

  file)
    echo "[zfs-send] Running: zfs ${SEND_ARGS[*]} > ${TARGET_FILE}"
    zfs "${SEND_ARGS[@]}" > "$TARGET_FILE"
    EXIT_CODE=$?
    if [ "$EXIT_CODE" -eq 0 ] && [ -f "$TARGET_FILE" ]; then
      BYTES_SENT=$(stat -c%s "$TARGET_FILE" 2>/dev/null || echo 0)
    fi
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[zfs-send] FAILED with exit code $EXIT_CODE"
else
  echo "[zfs-send] Completed in ${DURATION}s"
fi

# ── Emit structured JSON summary ────────────────────────────────────────────────

python3 - <<PYEOF
import json

exit_code    = $EXIT_CODE
duration     = $DURATION
bytes_sent   = $BYTES_SENT

result = {
    "success":          exit_code == 0,
    "exitCode":         exit_code,
    "sourceDataset":    "$SOURCE_DATASET",
    "sourceSnapshot":   "${RESOLVED_SNAP:-resume}",
    "incrementalFrom":  "${RESOLVED_INCR:-}",
    "targetType":       "$TARGET_TYPE",
    "targetDataset":    "$TARGET_DATASET",
    "recursive":        "$RECURSIVE" == "yes",
    "raw":              "$RAW" == "yes",
    "durationSeconds":  duration,
}

if "$TARGET_TYPE" == "file" and bytes_sent > 0:
    result["targetFile"]  = "$TARGET_FILE"
    result["bytesWritten"] = bytes_sent

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
