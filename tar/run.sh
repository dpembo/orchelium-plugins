#!/usr/bin/env bash
# Orchelium tar plugin — run.sh
# Receives a JSON blob as $1 containing all input values.

set -uo pipefail
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

parse_field() {
  local field="$1"
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$field',''))" <<< "$INPUT_JSON" 2>/dev/null \
    || echo ""
}

OPERATION=$(parse_field operation)
ARCHIVE=$(parse_field archive)
SOURCE=$(parse_field source)
DESTINATION=$(parse_field destination)
COMPRESSION=$(parse_field compression)
EXCLUDE=$(parse_field exclude)
EXTRA_OPTIONS=$(parse_field options)

: "${OPERATION:=create}"
: "${COMPRESSION:=auto}"

if [ -z "$ARCHIVE" ]; then
  echo '{"success":false,"error":"archive path is required"}'
  exit 1
fi

if [ "$OPERATION" = "create" ] && [ -z "$SOURCE" ]; then
  echo '{"success":false,"error":"source path is required for create operation"}'
  exit 1
fi

if ! command -v tar &>/dev/null; then
  echo '{"success":false,"error":"tar command not found on this host"}'
  exit 1
fi

# Resolve compression flag for create
get_compress_flag() {
  local algo="$1"
  local archive_name="$2"
  if [ "$algo" = "auto" ]; then
    case "$archive_name" in
      *.tar.gz|*.tgz)    echo "-z" ;;
      *.tar.bz2|*.tbz2)  echo "-j" ;;
      *.tar.xz|*.txz)    echo "-J" ;;
      *.tar.zst|*.tzst)  echo "--zstd" ;;
      *)                  echo "" ;;
    esac
  else
    case "$algo" in
      gzip)  echo "-z" ;;
      bzip2) echo "-j" ;;
      xz)    echo "-J" ;;
      zstd)  echo "--zstd" ;;
      none)  echo "" ;;
      *)     echo "" ;;
    esac
  fi
}

TAR_ARGS=()
START_TS=$(date +%s)

case "$OPERATION" in
  create)
    COMPRESS_FLAG=$(get_compress_flag "$COMPRESSION" "$ARCHIVE")
    TAR_ARGS+=("-c" "-v")
    [ -n "$COMPRESS_FLAG" ] && TAR_ARGS+=("$COMPRESS_FLAG")
    TAR_ARGS+=("-f" "$ARCHIVE")
    if [ -n "$EXCLUDE" ]; then
      read -ra EXCL_ARRAY <<< "$EXCLUDE"
      for pat in "${EXCL_ARRAY[@]}"; do
        TAR_ARGS+=("--exclude=$pat")
      done
    fi
    if [ -n "$EXTRA_OPTIONS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_OPTIONS"
      TAR_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    read -ra SRC_ARRAY <<< "$SOURCE"
    TAR_ARGS+=("${SRC_ARRAY[@]}")
    ;;

  extract)
    TAR_ARGS+=("-x" "-v" "-f" "$ARCHIVE")
    if [ -n "$DESTINATION" ]; then
      mkdir -p "$DESTINATION"
      TAR_ARGS+=("-C" "$DESTINATION")
    fi
    if [ -n "$EXTRA_OPTIONS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_OPTIONS"
      TAR_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    ;;

  list)
    TAR_ARGS+=("-t" "-v" "-f" "$ARCHIVE")
    if [ -n "$EXTRA_OPTIONS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_OPTIONS"
      TAR_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    ;;

  *)
    echo "{\"success\":false,\"error\":\"unknown operation: $OPERATION\"}"
    exit 1
    ;;
esac

echo "[tar] Running: tar ${TAR_ARGS[*]}"

OUTPUT=$(tar "${TAR_ARGS[@]}" 2>&1)
EXIT_CODE=$?
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

echo "$OUTPUT"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[tar] FAILED with exit code $EXIT_CODE"
fi

# Count file lines in output as a proxy for files processed
FILE_COUNT=$(echo "$OUTPUT" | grep -c '.' 2>/dev/null || true)
: "${FILE_COUNT:=0}"

# Archive size (for create/list context)
ARCHIVE_SIZE=0
if [ -f "$ARCHIVE" ]; then
  ARCHIVE_SIZE=$(stat -c%s "$ARCHIVE" 2>/dev/null || stat -f%z "$ARCHIVE" 2>/dev/null || echo 0)
fi

python3 - <<PYEOF
import json
result = {
    "success":         $EXIT_CODE == 0,
    "exitCode":        $EXIT_CODE,
    "operation":       "$OPERATION",
    "archive":         "$ARCHIVE",
    "durationSeconds": $DURATION,
    "fileCount":       $FILE_COUNT,
}
if "$OPERATION" == "create":
    result["source"]       = "$SOURCE"
    result["archiveBytes"] = $ARCHIVE_SIZE
if "$OPERATION" == "extract":
    dest = "$DESTINATION"
    result["destination"] = dest if dest else None
print(json.dumps(result))
PYEOF

exit $EXIT_CODE
