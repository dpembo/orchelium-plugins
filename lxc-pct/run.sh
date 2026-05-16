#!/usr/bin/env bash
# Orchelium lxc-pct plugin — run.sh
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

OPERATION=$(parse_field operation)
CTID=$(parse_field ctid)
EXEC_COMMAND=$(parse_field exec_command)
SNAPSHOT_NAME=$(parse_field snapshot_name)
SNAPSHOT_DESC=$(parse_field snapshot_description)
CLONE_TARGET_CTID=$(parse_field clone_target_ctid)
CLONE_HOSTNAME=$(parse_field clone_hostname)
CLONE_FULL=$(parse_field clone_full)
STOP_TIMEOUT=$(parse_field stop_timeout)
FORCE_STOP=$(parse_field force_stop)

# Apply defaults
: "${OPERATION:=start}"
: "${CLONE_FULL:=no}"
: "${FORCE_STOP:=no}"

# ── Validate ────────────────────────────────────────────────────────────────────

if ! command -v pct &>/dev/null; then
  echo "[lxc-pct] ERROR: pct not found — this plugin must run on a Proxmox node"
  echo '{"success":false,"error":"pct not found in PATH"}'
  exit 1
fi

case "$OPERATION" in
  start|stop|restart|exec|status|snapshot|rollback|destroy-snapshot|clone)
    if [ -z "$CTID" ]; then
      echo "{\"success\":false,\"error\":\"ctid is required for ${OPERATION} operation\"}"
      exit 1
    fi
    ;;
esac

case "$OPERATION" in
  exec)
    if [ -z "$EXEC_COMMAND" ]; then
      echo '{"success":false,"error":"exec_command is required for exec operation"}'
      exit 1
    fi
    ;;
  snapshot|rollback|destroy-snapshot)
    if [ -z "$SNAPSHOT_NAME" ]; then
      echo "{\"success\":false,\"error\":\"snapshot_name is required for ${OPERATION} operation\"}"
      exit 1
    fi
    ;;
  clone)
    if [ -z "$CLONE_TARGET_CTID" ]; then
      echo '{"success":false,"error":"clone_target_ctid is required for clone operation"}'
      exit 1
    fi
    ;;
esac

# ── Execute ─────────────────────────────────────────────────────────────────────

START_TS=$(date +%s)
PCT_OUTPUT=""
EXIT_CODE=0

case "$OPERATION" in

  # ── START ──────────────────────────────────────────────────────────────────
  start)
    echo "[lxc-pct] Running: pct start ${CTID}"
    PCT_OUTPUT=$(pct start "$CTID" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── STOP ───────────────────────────────────────────────────────────────────
  stop)
    STOP_ARGS=("stop" "$CTID")
    [ -n "$STOP_TIMEOUT" ] && [ "$STOP_TIMEOUT" != "0" ] && STOP_ARGS+=("--timeout" "$STOP_TIMEOUT")
    [ "$FORCE_STOP" = "yes" ] && STOP_ARGS+=("--skiplock")
    echo "[lxc-pct] Running: pct ${STOP_ARGS[*]}"
    PCT_OUTPUT=$(pct "${STOP_ARGS[@]}" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── RESTART ────────────────────────────────────────────────────────────────
  restart)
    RESTART_ARGS=("restart" "$CTID")
    [ -n "$STOP_TIMEOUT" ] && [ "$STOP_TIMEOUT" != "0" ] && RESTART_ARGS+=("--timeout" "$STOP_TIMEOUT")
    echo "[lxc-pct] Running: pct ${RESTART_ARGS[*]}"
    PCT_OUTPUT=$(pct "${RESTART_ARGS[@]}" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── EXEC ───────────────────────────────────────────────────────────────────
  exec)
    echo "[lxc-pct] Running: pct exec ${CTID} -- ${EXEC_COMMAND}"
    # pct exec passes everything after -- directly; wrap in sh -c for pipes/redirects
    PCT_OUTPUT=$(pct exec "$CTID" -- /bin/sh -c "$EXEC_COMMAND" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── STATUS ─────────────────────────────────────────────────────────────────
  status)
    echo "[lxc-pct] Running: pct status ${CTID}"
    PCT_OUTPUT=$(pct status "$CTID" 2>&1)
    EXIT_CODE=$?
    # Also grab config for hostname and other details
    PCT_CONFIG=$(pct config "$CTID" 2>/dev/null || echo "")
    ;;

  # ── SNAPSHOT ───────────────────────────────────────────────────────────────
  snapshot)
    SNAP_ARGS=("snapshot" "$CTID" "$SNAPSHOT_NAME")
    [ -n "$SNAPSHOT_DESC" ] && SNAP_ARGS+=("--description" "$SNAPSHOT_DESC")
    echo "[lxc-pct] Running: pct ${SNAP_ARGS[*]}"
    PCT_OUTPUT=$(pct "${SNAP_ARGS[@]}" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── ROLLBACK ───────────────────────────────────────────────────────────────
  rollback)
    echo "[lxc-pct] Running: pct rollback ${CTID} ${SNAPSHOT_NAME}"
    PCT_OUTPUT=$(pct rollback "$CTID" "$SNAPSHOT_NAME" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── DESTROY-SNAPSHOT ───────────────────────────────────────────────────────
  destroy-snapshot)
    echo "[lxc-pct] Running: pct delsnapshot ${CTID} ${SNAPSHOT_NAME}"
    PCT_OUTPUT=$(pct delsnapshot "$CTID" "$SNAPSHOT_NAME" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── CLONE ──────────────────────────────────────────────────────────────────
  clone)
    CLONE_ARGS=("clone" "$CTID" "$CLONE_TARGET_CTID")
    [ -n "$CLONE_HOSTNAME" ] && CLONE_ARGS+=("--hostname" "$CLONE_HOSTNAME")
    [ "$CLONE_FULL" = "yes" ] && CLONE_ARGS+=("--full")
    echo "[lxc-pct] Running: pct ${CLONE_ARGS[*]}"
    PCT_OUTPUT=$(pct "${CLONE_ARGS[@]}" 2>&1)
    EXIT_CODE=$?
    ;;

  # ── LIST ───────────────────────────────────────────────────────────────────
  list)
    echo "[lxc-pct] Running: pct list"
    PCT_OUTPUT=$(pct list 2>&1)
    EXIT_CODE=$?
    ;;

  *)
    echo "[lxc-pct] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))

echo "$PCT_OUTPUT"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[lxc-pct] FAILED with exit code $EXIT_CODE"
fi

# ── Emit structured JSON summary ────────────────────────────────────────────────

python3 - <<PYEOF
import json, re, sys

raw       = """$PCT_OUTPUT"""
config    = """${PCT_CONFIG:-}"""
operation = "$OPERATION"
ctid      = "$CTID"
exit_code = $EXIT_CODE
duration  = $DURATION

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "ctid":            ctid,
    "durationSeconds": duration,
}

if operation == "status":
    # pct status returns e.g. "status: running"
    m = re.search(r'status:\s+(\w+)', raw)
    if m:
        result["status"]  = m.group(1)
        result["running"] = m.group(1) == "running"
    # Pull hostname from config
    hm = re.search(r'^hostname:\s+(.+)', config, re.MULTILINE)
    if hm:
        result["hostname"] = hm.group(1).strip()

elif operation == "snapshot":
    result["snapshotName"] = "$SNAPSHOT_NAME"

elif operation == "rollback":
    result["rolledBackTo"] = "$SNAPSHOT_NAME"

elif operation == "clone":
    result["cloneCtid"]    = "$CLONE_TARGET_CTID"
    result["cloneHostname"] = "$CLONE_HOSTNAME"
    result["fullClone"]    = "$CLONE_FULL" == "yes"

elif operation == "list":
    containers = []
    for line in raw.strip().splitlines():
        # pct list output: VMID  Status  Lock  Name
        parts = line.split()
        if len(parts) >= 2 and parts[0].isdigit():
            containers.append({"ctid": parts[0], "status": parts[1], "name": parts[-1] if len(parts) >= 4 else ""})
    result["containerCount"] = len(containers)
    result["containers"]     = containers

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
