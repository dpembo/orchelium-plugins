#!/usr/bin/env bash
# Orchelium file-prune plugin — run.sh
# Deletes files matching a wildcard pattern that are older than a given number
# of days. Outputs structured JSON on stdout for the workflow context.

set -uo pipefail
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"success":false,"error":"No input JSON provided"}'
  exit 1
fi

parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" <<< "$INPUT_JSON" 2>/dev/null \
    || echo ""
}

DIRECTORY=$(parse_field directory)
PATTERN=$(parse_field pattern)
AGE_DAYS=$(parse_field age_days)
DRY_RUN=$(parse_field dry_run)
RECURSIVE=$(parse_field recursive)

# Apply defaults
: "${PATTERN:=*}"
: "${AGE_DAYS:=30}"
: "${DRY_RUN:=false}"
: "${RECURSIVE:=false}"

# ---- Validation ----------------------------------------------------------------

if [ -z "$DIRECTORY" ]; then
  echo '{"success":false,"error":"directory is required"}'
  exit 1
fi

if [ -z "$PATTERN" ]; then
  echo '{"success":false,"error":"pattern is required"}'
  exit 1
fi

if ! [[ "$AGE_DAYS" =~ ^[0-9]+$ ]]; then
  echo "{\"success\":false,\"error\":\"age_days must be a positive integer, got: $AGE_DAYS\"}"
  exit 1
fi

if [ ! -d "$DIRECTORY" ]; then
  echo "{\"success\":false,\"error\":\"directory not found: $DIRECTORY\"}"
  exit 1
fi

if [ ! -r "$DIRECTORY" ]; then
  echo "{\"success\":false,\"error\":\"directory is not readable: $DIRECTORY\"}"
  exit 1
fi

if [ "$DRY_RUN" != "true" ] && [ ! -w "$DIRECTORY" ]; then
  echo "{\"success\":false,\"error\":\"directory is not writable: $DIRECTORY\"}"
  exit 1
fi

# ---- Build find command --------------------------------------------------------

FIND_ARGS=("$DIRECTORY")

# Limit depth unless recursive is enabled
if [ "$RECURSIVE" != "true" ]; then
  FIND_ARGS+=(-maxdepth 1)
fi

FIND_ARGS+=(-name "$PATTERN" -type f -mtime +"$AGE_DAYS")

# ---- Execute -------------------------------------------------------------------

echo "[file-prune] Directory : $DIRECTORY"
echo "[file-prune] Pattern   : $PATTERN"
echo "[file-prune] Age (days): $AGE_DAYS"
echo "[file-prune] Recursive : $RECURSIVE"
echo "[file-prune] Dry run   : $DRY_RUN"
echo ""

if [ "$DRY_RUN" = "true" ]; then
  echo "[file-prune] DRY RUN — files that would be deleted:"
  mapfile -t MATCHED < <(find "${FIND_ARGS[@]}" 2>/dev/null)
  COUNT=${#MATCHED[@]}
  if [ "$COUNT" -eq 0 ]; then
    echo "[file-prune] No matching files found."
  else
    for f in "${MATCHED[@]}"; do
      echo "  $f"
    done
  fi
  echo ""
  echo "[file-prune] Dry run complete. $COUNT file(s) would be deleted."
  echo "{\"success\":true,\"dry_run\":true,\"deleted_count\":$COUNT}"
  exit 0
fi

# Live deletion — count files before deleting
mapfile -t TO_DELETE < <(find "${FIND_ARGS[@]}" 2>/dev/null)
COUNT=${#TO_DELETE[@]}

if [ "$COUNT" -eq 0 ]; then
  echo "[file-prune] No matching files found. Nothing to delete."
  echo "{\"success\":true,\"dry_run\":false,\"deleted_count\":0}"
  exit 0
fi

echo "[file-prune] Deleting $COUNT file(s)..."
for f in "${TO_DELETE[@]}"; do
  echo "  Deleting: $f"
done
echo ""

find "${FIND_ARGS[@]}" -delete
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[file-prune] ERROR: find -delete exited with code $EXIT_CODE"
  echo "{\"success\":false,\"error\":\"find -delete failed with exit code $EXIT_CODE\",\"deleted_count\":0}"
  exit "$EXIT_CODE"
fi

echo "[file-prune] Done. $COUNT file(s) deleted."
echo "{\"success\":true,\"dry_run\":false,\"deleted_count\":$COUNT}"
