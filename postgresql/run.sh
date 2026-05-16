#!/usr/bin/env bash
# Orchelium postgresql plugin — run.sh
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
DUMP_FORMAT=$(parse_field dump_format)
QUERY=$(parse_field query)
EXTRA_FLAGS=$(parse_field extra_flags)

: "${OPERATION:=dump}"
: "${HOST:=localhost}"
: "${PORT:=5432}"
: "${USER:=postgres}"
: "${DUMP_FORMAT:=custom}"

# ── PostgreSQL environment vars ─────────────────────────────────────────────────

export PGHOST="$HOST"
export PGPORT="$PORT"
export PGUSER="$USER"
[ -n "$PASSWORD_FILE" ] && export PGPASSFILE="$PASSWORD_FILE"

CONN_ARGS=(-h "$HOST" -p "$PORT" -U "$USER")

# ── Dump format flag ────────────────────────────────────────────────────────────

case "$DUMP_FORMAT" in
  custom)    FORMAT_FLAG="-Fc" ;;
  plain|sql) FORMAT_FLAG="-Fp" ;;
  tar)       FORMAT_FLAG="-Ft" ;;
  directory) FORMAT_FLAG="-Fd" ;;
  *)         FORMAT_FLAG="-Fc" ;;
esac

# ── Validate tool availability ──────────────────────────────────────────────────

if ! command -v psql &>/dev/null; then
  echo '[postgresql] ERROR: psql not found in PATH'
  echo '{"success":false,"error":"psql not found in PATH"}'
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

    echo "[postgresql] Dumping '${DATABASE}' → ${RESOLVED_DUMP} (format: ${DUMP_FORMAT})"

    # Plain format + .gz → stream through gzip
    if [[ "$RESOLVED_DUMP" == *.gz ]] && [ "$FORMAT_FLAG" = "-Fp" ]; then
      pg_dump "${CONN_ARGS[@]}" "$FORMAT_FLAG" $EXTRA_FLAGS "$DATABASE" \
        | gzip > "$RESOLVED_DUMP"
      EXIT_CODE=${PIPESTATUS[0]}
    else
      pg_dump "${CONN_ARGS[@]}" "$FORMAT_FLAG" -f "$RESOLVED_DUMP" \
        $EXTRA_FLAGS "$DATABASE"
      EXIT_CODE=$?
    fi

    [ -f "$RESOLVED_DUMP" ] && FILE_SIZE=$(stat -c%s "$RESOLVED_DUMP" 2>/dev/null || echo 0)
    ;;

  # ── DUMP-ALL ───────────────────────────────────────────────────────────────
  dump-all)
    [ -z "$DUMP_FILE" ] && { echo '{"success":false,"error":"dump_file required for dump-all"}'; exit 1; }

    RESOLVED_DUMP=$(date +"$DUMP_FILE")
    mkdir -p "$(dirname "$RESOLVED_DUMP")"

    echo "[postgresql] Dumping ALL databases → ${RESOLVED_DUMP}"

    if [[ "$RESOLVED_DUMP" == *.gz ]]; then
      pg_dumpall "${CONN_ARGS[@]}" $EXTRA_FLAGS | gzip > "$RESOLVED_DUMP"
      EXIT_CODE=${PIPESTATUS[0]}
    else
      pg_dumpall "${CONN_ARGS[@]}" $EXTRA_FLAGS > "$RESOLVED_DUMP"
      EXIT_CODE=$?
    fi

    [ -f "$RESOLVED_DUMP" ] && FILE_SIZE=$(stat -c%s "$RESOLVED_DUMP" 2>/dev/null || echo 0)
    ;;

  # ── RESTORE ────────────────────────────────────────────────────────────────
  restore)
    [ -z "$DATABASE" ]     && { echo '{"success":false,"error":"database required for restore"}'; exit 1; }
    [ -z "$RESTORE_FILE" ] && { echo '{"success":false,"error":"restore_file required for restore"}'; exit 1; }
    [ -f "$RESTORE_FILE" ] || { echo "{\"success\":false,\"error\":\"restore_file not found: ${RESTORE_FILE}\"}"; exit 1; }

    echo "[postgresql] Restoring '${RESTORE_FILE}' → ${DATABASE}"

    if [[ "$RESTORE_FILE" == *.sql.gz ]]; then
      gunzip -c "$RESTORE_FILE" | psql "${CONN_ARGS[@]}" $EXTRA_FLAGS -d "$DATABASE"
      EXIT_CODE=${PIPESTATUS[1]}
    elif [[ "$RESTORE_FILE" == *.sql ]]; then
      psql "${CONN_ARGS[@]}" $EXTRA_FLAGS -d "$DATABASE" -f "$RESTORE_FILE"
      EXIT_CODE=$?
    else
      # Custom / tar / directory format → pg_restore
      pg_restore "${CONN_ARGS[@]}" $EXTRA_FLAGS -d "$DATABASE" "$RESTORE_FILE"
      EXIT_CODE=$?
    fi
    ;;

  # ── QUERY ──────────────────────────────────────────────────────────────────
  query)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for query"}'; exit 1; }
    [ -z "$QUERY" ]    && { echo '{"success":false,"error":"query required for query operation"}'; exit 1; }

    echo "[postgresql] Query on '${DATABASE}'"
    psql "${CONN_ARGS[@]}" $EXTRA_FLAGS -d "$DATABASE" -c "$QUERY"
    EXIT_CODE=$?
    ;;

  # ── LIST-DATABASES ─────────────────────────────────────────────────────────
  list-databases)
    echo "[postgresql] Listing databases on ${HOST}:${PORT}"
    DB_LIST=$(psql "${CONN_ARGS[@]}" $EXTRA_FLAGS -t \
      -c "SELECT datname FROM pg_database WHERE datistemplate = false ORDER BY datname;" \
      2>&1)
    EXIT_CODE=$?
    echo "$DB_LIST"
    ;;

  # ── CREATE-DATABASE ────────────────────────────────────────────────────────
  create-database)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for create-database"}'; exit 1; }

    echo "[postgresql] Creating database '${DATABASE}'"
    createdb "${CONN_ARGS[@]}" $EXTRA_FLAGS "$DATABASE"
    EXIT_CODE=$?
    ;;

  # ── DROP-DATABASE ──────────────────────────────────────────────────────────
  drop-database)
    [ -z "$DATABASE" ] && { echo '{"success":false,"error":"database required for drop-database"}'; exit 1; }

    echo "[postgresql] Dropping database '${DATABASE}'"
    dropdb "${CONN_ARGS[@]}" $EXTRA_FLAGS "$DATABASE"
    EXIT_CODE=$?
    ;;

  # ── VACUUM ─────────────────────────────────────────────────────────────────
  vacuum)
    if [ -n "$DATABASE" ]; then
      echo "[postgresql] Running VACUUM ANALYZE on '${DATABASE}'"
      vacuumdb "${CONN_ARGS[@]}" $EXTRA_FLAGS --analyze --verbose "$DATABASE"
    else
      echo "[postgresql] Running VACUUM ANALYZE on ALL databases"
      vacuumdb "${CONN_ARGS[@]}" $EXTRA_FLAGS --analyze --verbose --all
    fi
    EXIT_CODE=$?
    ;;

  *)
    echo "[postgresql] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))
[ "$EXIT_CODE" -ne 0 ] && echo "[postgresql] FAILED (exit code ${EXIT_CODE})"

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

if operation in ("dump", "dump-all") and exit_code == 0:
    result["dumpFile"]      = dump_file
    result["fileSizeBytes"] = file_size
    result["fileSizeMB"]    = round(file_size / 1048576, 2)

elif operation == "list-databases":
    # psql -t output has leading spaces; strip and filter blanks
    dbs = [l.strip() for l in db_list_raw.strip().splitlines() if l.strip()]
    result["databases"]     = dbs
    result["databaseCount"] = len(dbs)

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
