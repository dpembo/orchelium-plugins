#!/usr/bin/env bash
# Orchelium sqlite plugin — run.sh
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
DATABASE_FILE=$(parse_field database_file)
DUMP_FILE=$(parse_field dump_file)
RESTORE_FILE=$(parse_field restore_file)
QUERY=$(parse_field query)
EXTRA_FLAGS=$(parse_field extra_flags)

: "${OPERATION:=dump}"

# ── Validate tool availability ──────────────────────────────────────────────────

if ! command -v sqlite3 &>/dev/null; then
  echo '[sqlite] ERROR: sqlite3 not found in PATH'
  echo '{"success":false,"error":"sqlite3 not found in PATH"}'
  exit 1
fi

if [ -z "$DATABASE_FILE" ]; then
  echo '{"success":false,"error":"database_file is required"}'
  exit 1
fi

START_TS=$(date +%s)
EXIT_CODE=0
FILE_SIZE=0
RESOLVED_DUMP=""
INTEGRITY_OK="true"
TABLE_LIST=""

# ── Execute ─────────────────────────────────────────────────────────────────────

case "$OPERATION" in

  # ── DUMP ───────────────────────────────────────────────────────────────────
  dump)
    [ -z "$DUMP_FILE" ] && { echo '{"success":false,"error":"dump_file required for dump"}'; exit 1; }
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    RESOLVED_DUMP=$(date +"$DUMP_FILE")
    mkdir -p "$(dirname "$RESOLVED_DUMP")"

    echo "[sqlite] Dumping '${DATABASE_FILE}' → ${RESOLVED_DUMP}"

    if [[ "$RESOLVED_DUMP" == *.gz ]]; then
      sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" .dump | gzip > "$RESOLVED_DUMP"
      EXIT_CODE=${PIPESTATUS[0]}
    else
      sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" .dump > "$RESOLVED_DUMP"
      EXIT_CODE=$?
    fi

    [ -f "$RESOLVED_DUMP" ] && FILE_SIZE=$(stat -c%s "$RESOLVED_DUMP" 2>/dev/null || echo 0)
    ;;

  # ── BACKUP (online hot-backup) ─────────────────────────────────────────────
  backup)
    [ -z "$DUMP_FILE" ] && { echo '{"success":false,"error":"dump_file required for backup"}'; exit 1; }
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    RESOLVED_DUMP=$(date +"$DUMP_FILE")
    mkdir -p "$(dirname "$RESOLVED_DUMP")"

    echo "[sqlite] Online backup '${DATABASE_FILE}' → ${RESOLVED_DUMP}"
    # .backup is SQLite's safe online backup — works on live databases
    sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" ".backup '${RESOLVED_DUMP}'"
    EXIT_CODE=$?

    [ -f "$RESOLVED_DUMP" ] && FILE_SIZE=$(stat -c%s "$RESOLVED_DUMP" 2>/dev/null || echo 0)
    ;;

  # ── RESTORE ────────────────────────────────────────────────────────────────
  restore)
    [ -z "$RESTORE_FILE" ] && { echo '{"success":false,"error":"restore_file required for restore"}'; exit 1; }
    [ -f "$RESTORE_FILE" ] || { echo "{\"success\":false,\"error\":\"restore_file not found: ${RESTORE_FILE}\"}"; exit 1; }

    mkdir -p "$(dirname "$DATABASE_FILE")"
    echo "[sqlite] Restoring '${RESTORE_FILE}' → ${DATABASE_FILE}"

    if [[ "$RESTORE_FILE" == *.gz ]]; then
      gunzip -c "$RESTORE_FILE" | sqlite3 $EXTRA_FLAGS "$DATABASE_FILE"
      EXIT_CODE=${PIPESTATUS[1]}
    else
      sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" < "$RESTORE_FILE"
      EXIT_CODE=$?
    fi
    ;;

  # ── QUERY ──────────────────────────────────────────────────────────────────
  query)
    [ -z "$QUERY" ] && { echo '{"success":false,"error":"query required for query operation"}'; exit 1; }
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    echo "[sqlite] Query on '${DATABASE_FILE}'"
    sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" "$QUERY"
    EXIT_CODE=$?
    ;;

  # ── VACUUM ─────────────────────────────────────────────────────────────────
  vacuum)
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    echo "[sqlite] Running VACUUM on '${DATABASE_FILE}'"
    sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" "VACUUM;"
    EXIT_CODE=$?
    ;;

  # ── INTEGRITY-CHECK ────────────────────────────────────────────────────────
  integrity-check)
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    echo "[sqlite] Integrity check on '${DATABASE_FILE}'"
    INTEGRITY_RESULT=$(sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" "PRAGMA integrity_check;" 2>&1)
    EXIT_CODE=$?
    echo "$INTEGRITY_RESULT"

    if [ "$INTEGRITY_RESULT" = "ok" ]; then
      INTEGRITY_OK="true"
    else
      INTEGRITY_OK="false"
      EXIT_CODE=1  # Force failure if DB is corrupt even if sqlite3 returned 0
    fi
    ;;

  # ── TABLES ─────────────────────────────────────────────────────────────────
  tables)
    [ -f "$DATABASE_FILE" ] || { echo "{\"success\":false,\"error\":\"database_file not found: ${DATABASE_FILE}\"}"; exit 1; }

    echo "[sqlite] Listing tables in '${DATABASE_FILE}'"
    TABLE_LIST=$(sqlite3 $EXTRA_FLAGS "$DATABASE_FILE" \
      "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name;" 2>&1)
    EXIT_CODE=$?
    echo "$TABLE_LIST"
    ;;

  *)
    echo "[sqlite] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

DURATION=$(( $(date +%s) - START_TS ))
[ "$EXIT_CODE" -ne 0 ] && echo "[sqlite] FAILED (exit code ${EXIT_CODE})"

# ── JSON summary ────────────────────────────────────────────────────────────────

python3 - <<PYEOF
import json

operation     = "$OPERATION"
exit_code     = $EXIT_CODE
duration      = $DURATION
database_file = "$DATABASE_FILE"
dump_file     = "$RESOLVED_DUMP"
file_size     = $FILE_SIZE
integrity_ok  = "$INTEGRITY_OK" == "true"
table_list    = """$TABLE_LIST"""

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "databaseFile":    database_file,
    "durationSeconds": duration,
}

if operation in ("dump", "backup") and exit_code == 0:
    result["dumpFile"]      = dump_file
    result["fileSizeBytes"] = file_size
    result["fileSizeMB"]    = round(file_size / 1048576, 2)

elif operation == "integrity-check":
    result["integrityOk"] = integrity_ok

elif operation == "tables":
    tables = [t.strip() for t in table_list.strip().splitlines() if t.strip()]
    result["tables"]     = tables
    result["tableCount"] = len(tables)

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
