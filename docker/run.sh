#!/usr/bin/env bash
# Orchelium docker plugin — run.sh
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
CONTAINER=$(parse_field container)
IMAGE=$(parse_field image)
EXEC_COMMAND=$(parse_field exec_command)
RUN_COMMAND=$(parse_field run_command)
RUN_VOLUMES=$(parse_field run_volumes)
RUN_ENV=$(parse_field run_env)
RUN_NETWORK=$(parse_field run_network)
RUN_EXTRA_FLAGS=$(parse_field run_extra_flags)
STOP_TIMEOUT=$(parse_field stop_timeout)
LOGS_TAIL=$(parse_field logs_tail)
LOGS_SINCE=$(parse_field logs_since)
PS_ALL=$(parse_field ps_all)
PRUNE_VOLUMES=$(parse_field prune_volumes)
DOCKER_HOST_OVERRIDE=$(parse_field docker_host)

# Apply defaults
: "${OPERATION:=start}"
: "${LOGS_TAIL:=100}"
: "${PS_ALL:=no}"
: "${PRUNE_VOLUMES:=no}"

# ── Validate ────────────────────────────────────────────────────────────────────

if ! command -v docker &>/dev/null; then
  echo "[docker] ERROR: docker is not installed on this agent"
  echo '{"success":false,"error":"docker not found in PATH"}'
  exit 1
fi

# Override Docker host if specified
if [ -n "$DOCKER_HOST_OVERRIDE" ]; then
  export DOCKER_HOST="$DOCKER_HOST_OVERRIDE"
fi

# Verify Docker daemon is reachable
if ! docker info &>/dev/null; then
  echo "[docker] ERROR: cannot connect to Docker daemon (DOCKER_HOST=${DOCKER_HOST:-/var/run/docker.sock})"
  echo '{"success":false,"error":"Docker daemon not reachable"}'
  exit 1
fi

# Per-operation validation
case "$OPERATION" in
  start|stop|restart|exec|rm|logs|inspect)
    if [ -z "$CONTAINER" ]; then
      echo "{\"success\":false,\"error\":\"container is required for ${OPERATION} operation\"}"
      exit 1
    fi
    ;;
  run|pull)
    if [ -z "$IMAGE" ]; then
      echo "{\"success\":false,\"error\":\"image is required for ${OPERATION} operation\"}"
      exit 1
    fi
    ;;
  exec)
    if [ -z "$EXEC_COMMAND" ]; then
      echo '{"success":false,"error":"exec_command is required for exec operation"}'
      exit 1
    fi
    ;;
esac

# ── Execute ─────────────────────────────────────────────────────────────────────

START_TS=$(date +%s)
DOCKER_OUTPUT=""
EXIT_CODE=0

case "$OPERATION" in

  # ── START ──────────────────────────────────────────────────────────────────
  start)
    read -ra CT_ARRAY <<< "$CONTAINER"
    echo "[docker] Running: docker start ${CT_ARRAY[*]}"
    run_and_capture docker start "${CT_ARRAY[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── STOP ───────────────────────────────────────────────────────────────────
  stop)
    read -ra CT_ARRAY <<< "$CONTAINER"
    STOP_ARGS=("stop")
    [ -n "$STOP_TIMEOUT" ] && [ "$STOP_TIMEOUT" != "0" ] && STOP_ARGS+=("--time" "$STOP_TIMEOUT")
    STOP_ARGS+=("${CT_ARRAY[@]}")
    echo "[docker] Running: docker ${STOP_ARGS[*]}"
    run_and_capture docker "${STOP_ARGS[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── RESTART ────────────────────────────────────────────────────────────────
  restart)
    read -ra CT_ARRAY <<< "$CONTAINER"
    RESTART_ARGS=("restart")
    [ -n "$STOP_TIMEOUT" ] && [ "$STOP_TIMEOUT" != "0" ] && RESTART_ARGS+=("--time" "$STOP_TIMEOUT")
    RESTART_ARGS+=("${CT_ARRAY[@]}")
    echo "[docker] Running: docker ${RESTART_ARGS[*]}"
    run_and_capture docker "${RESTART_ARGS[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── EXEC ───────────────────────────────────────────────────────────────────
  exec)
    echo "[docker] Running: docker exec ${CONTAINER} /bin/sh -c '${EXEC_COMMAND}'"
    run_and_capture docker exec "$CONTAINER" /bin/sh -c "$EXEC_COMMAND"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── RUN ────────────────────────────────────────────────────────────────────
  run)
    RUN_ARGS=("run" "--rm")

    # Volume mounts
    if [ -n "$RUN_VOLUMES" ]; then
      read -ra VOL_ARRAY <<< "$RUN_VOLUMES"
      for vol in "${VOL_ARRAY[@]}"; do
        RUN_ARGS+=("-v" "$vol")
      done
    fi

    # Environment variables
    if [ -n "$RUN_ENV" ]; then
      read -ra ENV_ARRAY <<< "$RUN_ENV"
      for env in "${ENV_ARRAY[@]}"; do
        RUN_ARGS+=("-e" "$env")
      done
    fi

    # Network
    [ -n "$RUN_NETWORK" ] && RUN_ARGS+=("--network" "$RUN_NETWORK")

    # Extra flags
    if [ -n "$RUN_EXTRA_FLAGS" ]; then
      read -ra EF <<< "$RUN_EXTRA_FLAGS"
      RUN_ARGS+=("${EF[@]}")
    fi

    RUN_ARGS+=("$IMAGE")

    # Entrypoint args
    if [ -n "$RUN_COMMAND" ]; then
      read -ra CMD_ARRAY <<< "$RUN_COMMAND"
      RUN_ARGS+=("${CMD_ARRAY[@]}")
    fi

    echo "[docker] Running: docker ${RUN_ARGS[*]}"
  run_and_capture docker "${RUN_ARGS[@]}"
  DOCKER_OUTPUT=$CAPTURED_OUTPUT
  EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── PULL ───────────────────────────────────────────────────────────────────
  pull)
    echo "[docker] Running: docker pull ${IMAGE}"
    run_and_capture docker pull "$IMAGE"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── RM ─────────────────────────────────────────────────────────────────────
  rm)
    read -ra CT_ARRAY <<< "$CONTAINER"
    echo "[docker] Running: docker rm ${CT_ARRAY[*]}"
    run_and_capture docker rm "${CT_ARRAY[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── LOGS ───────────────────────────────────────────────────────────────────
  logs)
    LOG_ARGS=("logs" "--tail" "$LOGS_TAIL" "--timestamps")
    [ -n "$LOGS_SINCE" ] && LOG_ARGS+=("--since" "$LOGS_SINCE")
    LOG_ARGS+=("$CONTAINER")
    echo "[docker] Running: docker ${LOG_ARGS[*]}"
    run_and_capture docker "${LOG_ARGS[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── PS ─────────────────────────────────────────────────────────────────────
  ps)
    PS_ARGS=("ps" "--format" "{{json .}}")
    [ "$PS_ALL" = "yes" ] && PS_ARGS+=("-a")
    echo "[docker] Running: docker ${PS_ARGS[*]}"
    run_and_capture docker "${PS_ARGS[@]}"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── INSPECT ────────────────────────────────────────────────────────────────
  inspect)
    echo "[docker] Running: docker inspect ${CONTAINER}"
    run_and_capture docker inspect "$CONTAINER"
    DOCKER_OUTPUT=$CAPTURED_OUTPUT
    EXIT_CODE=$CAPTURED_EXIT_CODE
    ;;

  # ── PRUNE ──────────────────────────────────────────────────────────────────
  prune)
    PRUNE_OUTPUT=""
    echo "[docker] Pruning stopped containers..."
    run_and_capture docker container prune -f
    PRUNE_OUTPUT+="$CAPTURED_OUTPUT"$'\n'
    EXIT_CODE=$CAPTURED_EXIT_CODE
    echo "[docker] Pruning dangling images..."
    run_and_capture docker image prune -f
    PRUNE_OUTPUT+="$CAPTURED_OUTPUT"$'\n'
    [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=$CAPTURED_EXIT_CODE
    echo "[docker] Pruning unused networks..."
    run_and_capture docker network prune -f
    PRUNE_OUTPUT+="$CAPTURED_OUTPUT"$'\n'
    [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=$CAPTURED_EXIT_CODE
    if [ "$PRUNE_VOLUMES" = "yes" ]; then
      echo "[docker] Pruning unused volumes..."
      run_and_capture docker volume prune -f
      PRUNE_OUTPUT+="$CAPTURED_OUTPUT"$'\n'
      [ "$EXIT_CODE" -eq 0 ] && EXIT_CODE=$CAPTURED_EXIT_CODE
    fi
    DOCKER_OUTPUT="$PRUNE_OUTPUT"
    ;;

  *)
    echo "[docker] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[docker] FAILED with exit code $EXIT_CODE"
fi

# ── Emit structured JSON summary ────────────────────────────────────────────────

python3 - <<PYEOF
import json, sys

raw        = """$DOCKER_OUTPUT"""
operation  = "$OPERATION"
exit_code  = $EXIT_CODE
duration   = $DURATION
container  = "$CONTAINER"
image      = "$IMAGE"

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "durationSeconds": duration,
}

if container:
    result["container"] = container
if image:
    result["image"] = image

if operation == "ps":
    containers = []
    for line in raw.strip().splitlines():
        line = line.strip()
        if line.startswith('{'):
            try:
                containers.append(json.loads(line))
            except json.JSONDecodeError:
                pass
    result["containerCount"] = len(containers)
    result["containers"]     = containers

elif operation == "inspect":
    try:
        data = json.loads(raw.strip())
        if isinstance(data, list) and data:
            info = data[0]
            result["name"]    = info.get("Name", "").lstrip("/")
            result["status"]  = info.get("State", {}).get("Status", "")
            result["running"] = info.get("State", {}).get("Running", False)
            result["image"]   = info.get("Config", {}).get("Image", "")
    except (json.JSONDecodeError, TypeError, KeyError):
        pass

elif operation == "prune":
    # Extract reclaimed space from prune output
    import re
    total = 0
    for m in re.finditer(r'Total reclaimed space:\s+([\d.]+)\s*(\w+)', raw):
        val, unit = float(m.group(1)), m.group(2).upper()
        multipliers = {"B": 1, "KB": 1024, "MB": 1024**2, "GB": 1024**3}
        total += int(val * multipliers.get(unit, 1))
    if total:
        result["reclaimedBytes"] = total

elif operation == "logs":
    result["lineCount"] = len([l for l in raw.splitlines() if l.strip()])

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
