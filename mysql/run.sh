#!/usr/bin/env bash
# Orchelium mysql plugin — run.sh
# INPUT_JSON is injected by the Orchelium hub as a variable prepended to this script.

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
HOST=$(parse_field host)
PORT=$(parse_field port)
USER=$(parse_field user)
PASSWORD_FILE=$(parse_field password_file)
DATABASE=$(parse_field database)
DUMP_FILE=$(parse_field dump_file)
RESTORE_FILE=$(parse_field restore_file)
QUERY=$(parse_field query)
EXTRA_FLAGS=$(parse_field extra_flags)

: "${OPERATION:=dump}"
: "${HOST:=localhost}"
: "${PORT:=3306}"
: "${USER:=root}"

# ── Build connection args ───────────────────────────────────────────────────────

CONN_BASE=(-h "$HOST" -P "$PORT" -u "$USER")
if [ -n "$PASSWORD_FILE" ]; then
  CONN_ARGS=("--defaults-extra-file=${PASSWORD_FILE}" "${CONN_BASE[@]}")
else
  CONN_ARGS=("${CONN_BASE[@]}")
fi

# ── Validate tool availability ──────────────────────────────────────────────────

if ! command -v mysql &>/dev/null; then
  echo '[mysql] ERROR: mysql client not found in PATH'
  echo '{"success":false,"error":"mysql not found in PATH"}'
  exit 1
fi

START_TS=$(date +%s)
EXIT_CODE=0
FILE_SIZE=0
DB_LIST=""
RESOLVED_DUMP=""

# ── Execute ─────────────────────────────────────────────────────────────────────

case "$OPERATION" in

  # ── DUMP ───────────────────────────────────────────────────────────────────
  dump)
    [ -z "$DATABASE" ]  && { echo '{"success":false,"error":"database required for dump"}'; exit 1; }
    [ -z "$DUMP_FILE" ] && { echo '{"success":false,"error":"dump_file required for dump"}'; exit 1; }

    RESOLVED_DUMP=$(date +"$DUMP_FILE")
    mkdir -p "$(dirname "$RESOLVED_DUMP")"

    if [ "$DATABASE" = "ALL" ]; then
      DB_ARGS=(--all-databases)
    else
      DB_ARGS=("$DATABASE")
    fi

    echo "[mysql] Dumping '${DATABASE}' → ${RESOLVED_DUMP}"

    if [[ "$RESOLVED_DUMP" == *.gz ]]; then
      mysqldump "${CONN_ARGS[@]}" $EXTRA_FLAGS "${DB_ARGS[@]}" | gzip > "$RESOLVED_DUMP"
      EXIT_CODE=${PIPESTATUS[0]}
    else
      mysqldump "${CONN_ARGS[@]}" $EXTRA_FLAGS "${DB_ARGS[@]}" > "$RESOLVED_DUMP"
      EXIT_CODE=$?
    fi

    [ -f "$RESOLVED_DUMP" ] && FILE_SIZE=$(stat -c%s "$RESOLVED_DUMP" 2>/dev/null || echo 0)
    ;;

  # ── RESTORE ────────────────────────────────────────────────────────────────
  restore)
    [ -z "$DATABASE" ]     && { echo '{"success":false,"error":"database required for restore"}'; exit 1; }
    [ -z "$RESTORE_FILE" ] && { echo '{"success":false,"error":"restore_file required for restore"}'; exit 1; }
    [ -f "$RESTORE_FILE" ] || { echo "{\"success\":false,\"error\":\"restore_file not found: ${RESTORE_FILE}\"}"; exit 1; }

    echo "[mysql] Restoring '${RESTORE_FILE}' → ${DATABASE}"

    if [[ "$RESTORE_FILE" == *.gz ]]; then
      gunzip -c "$RESTORE_FILE" | mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS "$DATABASE"
      EXIT_CODE=${PIPESTATUS[1]}
    else
      mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS "$DATABASE" < "$RESTORE_FILE"
      EXIT_CODE=$?
    fi
    ;;

  # ── QUERY ──────────────────────────────────────────────────────────────────
  query)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for query"}'; exit 1; }
    [ -z "$QUERY" ]    && { echo '{"success":false,"error":"query required for query operation"}'; exit 1; }

    echo "[mysql] Query on '${DATABASE}'"
    mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS --table "$DATABASE" -e "$QUERY"
    EXIT_CODE=$?
    ;;

  # ── LIST-DATABASES ─────────────────────────────────────────────────────────
  list-databases)
    echo "[mysql] Listing databases on ${HOST}:${PORT}"
    DB_LIST=$(mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS --batch --silent \
      -e "SHOW DATABASES;" 2>&1)
    EXIT_CODE=$?
    echo "$DB_LIST"
    ;;

  # ── CREATE-DATABASE ────────────────────────────────────────────────────────
  create-database)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for create-database"}'; exit 1; }

    echo "[mysql] Creating database '${DATABASE}'"
    mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS \
      -e "CREATE DATABASE IF NOT EXISTS \`${DATABASE}\`;"
    EXIT_CODE=$?
    ;;

  # ── DROP-DATABASE ──────────────────────────────────────────────────────────
  drop-database)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for drop-database"}'; exit 1; }

    echo "[mysql] Dropping database '${DATABASE}'"
    mysql "${CONN_ARGS[@]}" $EXTRA_FLAGS \
      -e "DROP DATABASE IF EXISTS \`${DATABASE}\`;"
    EXIT_CODE=$?
    ;;

  # ── CHECK ──────────────────────────────────────────────────────────────────
  check)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for check"}'; exit 1; }

    echo "[mysql] Checking database '${DATABASE}'"
    mysqlcheck "${CONN_ARGS[@]}" $EXTRA_FLAGS --auto-repair "$DATABASE"
    EXIT_CODE=$?
    ;;

  *)
    echo "[mysql] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))
[ "$EXIT_CODE" -ne 0 ] && echo "[mysql] FAILED (exit code ${EXIT_CODE})"

# ── JSON summary ────────────────────────────────────────────────────────────────

python3 - <<PYEOF
import json

operation   = "$OPERATION"
exit_code   = $EXIT_CODE
duration    = $DURATION
database    = "$DATABASE"
dump_file   = "$RESOLVED_DUMP"
file_size   = $FILE_SIZE
db_list_raw = """$DB_LIST"""

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "durationSeconds": duration,
}

if database:
    result["database"] = database

if operation == "dump" and exit_code == 0:
    result["dumpFile"]      = dump_file
    result["fileSizeBytes"] = file_size
    result["fileSizeMB"]    = round(file_size / 1048576, 2)

elif operation == "list-databases":
    dbs = [l.strip() for l in db_list_raw.strip().splitlines() if l.strip()]
    result["databases"]     = dbs
    result["databaseCount"] = len(dbs)

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
