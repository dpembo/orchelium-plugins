#!/usr/bin/env bash
# Orchelium borg plugin — run.sh
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
REPO=$(parse_field repo)
ARCHIVE_NAME=$(parse_field archive_name)
PATHS=$(parse_field paths)
PASSPHRASE_FILE=$(parse_field passphrase_file)
COMPRESSION=$(parse_field compression)
EXCLUDE=$(parse_field exclude)
PRUNE_POLICY=$(parse_field prune_policy)
ARCHIVE_REF=$(parse_field archive_ref)
EXTRA_FLAGS=$(parse_field extra_flags)

# Apply defaults
: "${OPERATION:=create}"
: "${ARCHIVE_NAME:={hostname}-{now:%Y-%m-%dT%H:%M:%S}}"
: "${COMPRESSION:=lz4}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$REPO" ]; then
  echo '{"success":false,"error":"repo is required"}'
  exit 1
fi

if ! command -v borg &>/dev/null; then
  echo "[borg] ERROR: borg is not installed on this agent"
  echo '{"success":false,"error":"borg not found in PATH"}'
  exit 1
fi

# ── Authentication ──────────────────────────────────────────────────────────────

if [ -n "$PASSPHRASE_FILE" ]; then
  if [ ! -f "$PASSPHRASE_FILE" ]; then
    echo "[borg] ERROR: passphrase file does not exist: $PASSPHRASE_FILE"
    echo '{"success":false,"error":"passphrase file not found"}'
    exit 1
  fi
  export BORG_PASSPHRASE
  BORG_PASSPHRASE=$(cat "$PASSPHRASE_FILE")
elif [ -z "${BORG_PASSPHRASE:-}" ]; then
  echo "[borg] WARNING: no passphrase_file set and BORG_PASSPHRASE is not in environment"
fi

# Suppress interactive passphrase prompt — fail fast if credentials missing
export BORG_PASSCOMMAND="${BORG_PASSCOMMAND:-}"

# ── Build command ───────────────────────────────────────────────────────────────

BORG_ARGS=()

case "$OPERATION" in
  create)
    if [ -z "$PATHS" ]; then
      echo '{"success":false,"error":"paths is required for create operation"}'
      exit 1
    fi
    BORG_ARGS+=("create" "--compression" "$COMPRESSION" "--json")
    if [ -n "$EXCLUDE" ]; then
      read -ra EXCL_ARRAY <<< "$EXCLUDE"
      for excl in "${EXCL_ARRAY[@]}"; do
        BORG_ARGS+=("--exclude" "$excl")
      done
    fi
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    BORG_ARGS+=("${REPO}::${ARCHIVE_NAME}")
    read -ra PATH_ARRAY <<< "$PATHS"
    BORG_ARGS+=("${PATH_ARRAY[@]}")
    ;;

  prune)
    BORG_ARGS+=("prune" "--json")
    if [ -n "$PRUNE_POLICY" ]; then
      read -ra POLICY_ARRAY <<< "$PRUNE_POLICY"
      BORG_ARGS+=("${POLICY_ARRAY[@]}")
    fi
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    BORG_ARGS+=("$REPO")
    ;;

  check)
    BORG_ARGS+=("check")
    if [ -n "$ARCHIVE_REF" ]; then
      BORG_ARGS+=("${REPO}::${ARCHIVE_REF}")
    else
      BORG_ARGS+=("$REPO")
    fi
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    ;;

  list)
    BORG_ARGS+=("list" "--json")
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    BORG_ARGS+=("$REPO")
    ;;

  info)
    BORG_ARGS+=("info" "--json")
    if [ -n "$ARCHIVE_REF" ]; then
      BORG_ARGS+=("${REPO}::${ARCHIVE_REF}")
    else
      BORG_ARGS+=("$REPO")
    fi
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    ;;

  compact)
    BORG_ARGS+=("compact")
    if [ -n "$EXTRA_FLAGS" ]; then
      read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
      BORG_ARGS+=("${EXTRA_ARRAY[@]}")
    fi
    BORG_ARGS+=("$REPO")
    ;;

  *)
    echo "[borg] ERROR: unknown operation: $OPERATION"
    echo '{"success":false,"error":"unknown operation"}'
    exit 1
    ;;
esac

# ── Execute ─────────────────────────────────────────────────────────────────────

echo "[borg] Running: borg ${BORG_ARGS[*]}"

START_TS=$(date +%s)
BORG_OUTPUT=$(borg "${BORG_ARGS[@]}" 2>&1)
EXIT_CODE=$?
DURATION=$(( $(date +%s) - START_TS ))

echo "$BORG_OUTPUT"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[borg] FAILED with exit code $EXIT_CODE"
fi

# ── Parse JSON output for workflow context ──────────────────────────────────────
# borg --json emits a structured object for create, list, info, prune.

python3 - <<PYEOF
import json, re, sys

raw       = """$BORG_OUTPUT"""
operation = "$OPERATION"
exit_code = $EXIT_CODE
duration  = $DURATION

result = {
    "success":         exit_code == 0,
    "exitCode":        exit_code,
    "operation":       operation,
    "durationSeconds": duration,
}

# Try to find the JSON object emitted by borg --json (usually the last {...} block)
for line in reversed(raw.strip().splitlines()):
    line = line.strip()
    if line.startswith('{'):
        try:
            data = json.loads(line)
            if operation == "create":
                stats = data.get("archive", {}).get("stats", {})
                result["archiveName"]       = data.get("archive", {}).get("name", "")
                result["originalSize"]      = stats.get("original_size", 0)
                result["compressedSize"]    = stats.get("compressed_size", 0)
                result["dedupSize"]         = stats.get("deduplicated_size", 0)
                result["nFiles"]            = stats.get("nfiles", 0)
            elif operation == "list":
                archives = data.get("archives", [])
                result["archiveCount"] = len(archives)
                result["archives"]     = [a.get("name", "") for a in archives]
            elif operation in ("info", "prune"):
                cache = data.get("cache", {}).get("stats", {})
                result["totalSize"]    = cache.get("total_size", 0)
                result["uniqueSize"]   = cache.get("unique_size", 0)
        except (json.JSONDecodeError, TypeError, AttributeError):
            pass
        break

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
