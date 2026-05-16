#!/usr/bin/env bash
# Orchelium s3 plugin — run.sh
# Supports sync, upload, download, ls, delete, mb, presign against AWS S3
# or any S3-compatible object store (MinIO, Wasabi, Cloudflare R2, etc.)
#
# Credentials are sourced from:
#   1. credentials_file input → sets AWS_SHARED_CREDENTIALS_FILE
#   2. profile input → sets AWS_PROFILE
#   3. Agent environment (AWS_ACCESS_KEY_ID / AWS_SECRET_ACCESS_KEY / instance role)

set -uo pipefail
exec 2>&1

INPUT_JSON="${INPUT_JSON:-${1:-}}"

if [ -z "$INPUT_JSON" ]; then
  echo '{"error":"No input JSON provided"}'
  exit 1
fi

# ── Parse inputs ────────────────────────────────────────────────────────────────

parse_field() {
  python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('$1',''))" \
    <<< "$INPUT_JSON" 2>/dev/null || echo ""
}

OPERATION=$(parse_field operation)
BUCKET=$(parse_field bucket)
PREFIX=$(parse_field prefix)
LOCAL_PATH=$(parse_field local_path)
CREDENTIALS_FILE=$(parse_field credentials_file)
PROFILE=$(parse_field profile)
REGION=$(parse_field region)
ENDPOINT_URL=$(parse_field endpoint_url)
STORAGE_CLASS=$(parse_field storage_class)
DELETE_FLAG=$(parse_field delete)
DRY_RUN=$(parse_field dry_run)
EXCLUDE=$(parse_field exclude)
INCLUDE=$(parse_field include)
PRESIGN_EXPIRES=$(parse_field presign_expires)
EXTRA_FLAGS=$(parse_field extra_flags)

: "${OPERATION:=sync}"
: "${DELETE_FLAG:=no}"
: "${DRY_RUN:=no}"
: "${PRESIGN_EXPIRES:=3600}"

# ── Validate tool availability ──────────────────────────────────────────────────

if ! command -v aws &>/dev/null; then
  echo "[s3] ERROR: AWS CLI (aws) is not installed on this agent"
  echo '{"success":false,"error":"aws CLI not found in PATH"}'
  exit 1
fi

# ── Set credentials / endpoint via environment ──────────────────────────────────

if [ -n "$CREDENTIALS_FILE" ]; then
  if [ ! -f "$CREDENTIALS_FILE" ]; then
    echo "[s3] ERROR: credentials file not found: $CREDENTIALS_FILE"
    echo '{"success":false,"error":"credentials file not found"}'
    exit 1
  fi
  export AWS_SHARED_CREDENTIALS_FILE="$CREDENTIALS_FILE"
fi

if [ -n "$PROFILE" ]; then
  export AWS_PROFILE="$PROFILE"
fi

# ── Build common AWS CLI args ───────────────────────────────────────────────────

AWS_ARGS=()
[ -n "$REGION" ]       && AWS_ARGS+=(--region "$REGION")
[ -n "$ENDPOINT_URL" ] && AWS_ARGS+=(--endpoint-url "$ENDPOINT_URL")

# ── Helpers ─────────────────────────────────────────────────────────────────────

# Build full S3 URI: s3://bucket[/prefix]
s3_uri() {
  local bucket="$1"
  local prefix="${2:-}"
  # Remove leading slash from prefix if present
  prefix="${prefix#/}"
  if [ -n "$prefix" ]; then
    echo "s3://${bucket}/${prefix}"
  else
    echo "s3://${bucket}"
  fi
}

# Validate that a required field is set
require_field() {
  local name="$1"
  local value="$2"
  if [ -z "$value" ]; then
    echo "[s3] ERROR: '${name}' is required for operation '${OPERATION}'"
    echo "{\"success\":false,\"error\":\"${name} is required\"}"
    exit 1
  fi
}

# ── Run operation ───────────────────────────────────────────────────────────────

START_TS=$(date +%s)

case "$OPERATION" in

  # ── sync ────────────────────────────────────────────────────────────────────
  sync)
    require_field "bucket"     "$BUCKET"
    require_field "local_path" "$LOCAL_PATH"

    S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    SYNC_ARGS=("${AWS_ARGS[@]}" s3 sync "$LOCAL_PATH" "$S3_URI")

    [ "$DELETE_FLAG" = "yes" ] && SYNC_ARGS+=(--delete)
    [ "$DRY_RUN"     = "yes" ] && SYNC_ARGS+=(--dryrun)
    [ -n "$STORAGE_CLASS" ]    && SYNC_ARGS+=(--storage-class "$STORAGE_CLASS")

    # Exclude patterns
    for pat in $EXCLUDE; do
      SYNC_ARGS+=(--exclude "$pat")
    done
    # Include patterns
    for pat in $INCLUDE; do
      SYNC_ARGS+=(--include "$pat")
    done

    # Extra flags (word-split intentional)
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && SYNC_ARGS+=($EXTRA_FLAGS)

    echo "[s3] sync: ${LOCAL_PATH} → ${S3_URI}"
    [ "$DRY_RUN" = "yes" ] && echo "[s3] NOTE: dry-run mode — no changes will be made"
    aws "${SYNC_ARGS[@]}"
    ;;

  # ── upload ──────────────────────────────────────────────────────────────────
  upload)
    require_field "bucket"     "$BUCKET"
    require_field "local_path" "$LOCAL_PATH"

    S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    CP_ARGS=("${AWS_ARGS[@]}" s3 cp "$LOCAL_PATH" "$S3_URI")

    # If local_path is a directory, add --recursive
    [ -d "$LOCAL_PATH" ] && CP_ARGS+=(--recursive)

    [ "$DRY_RUN"          = "yes" ] && CP_ARGS+=(--dryrun)
    [ -n "$STORAGE_CLASS" ]         && CP_ARGS+=(--storage-class "$STORAGE_CLASS")

    for pat in $EXCLUDE; do CP_ARGS+=(--exclude "$pat"); done
    for pat in $INCLUDE; do CP_ARGS+=(--include "$pat"); done
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && CP_ARGS+=($EXTRA_FLAGS)

    echo "[s3] upload: ${LOCAL_PATH} → ${S3_URI}"
    aws "${CP_ARGS[@]}"
    ;;

  # ── download ─────────────────────────────────────────────────────────────────
  download)
    require_field "bucket"     "$BUCKET"
    require_field "local_path" "$LOCAL_PATH"

    S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    CP_ARGS=("${AWS_ARGS[@]}" s3 cp "$S3_URI" "$LOCAL_PATH")

    # If prefix looks like a directory (ends with / or no extension), add --recursive
    if [[ "$PREFIX" == */ ]] || [ -d "$LOCAL_PATH" ]; then
      CP_ARGS+=(--recursive)
    fi

    [ "$DRY_RUN" = "yes" ] && CP_ARGS+=(--dryrun)
    for pat in $EXCLUDE; do CP_ARGS+=(--exclude "$pat"); done
    for pat in $INCLUDE; do CP_ARGS+=(--include "$pat"); done
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && CP_ARGS+=($EXTRA_FLAGS)

    echo "[s3] download: ${S3_URI} → ${LOCAL_PATH}"
    aws "${CP_ARGS[@]}"
    ;;

  # ── ls ───────────────────────────────────────────────────────────────────────
  ls)
    S3_URI=""
    if [ -n "$BUCKET" ]; then
      S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    fi

    LS_ARGS=("${AWS_ARGS[@]}" s3 ls)
    [ -n "$S3_URI" ] && LS_ARGS+=("$S3_URI")
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && LS_ARGS+=($EXTRA_FLAGS)

    echo "[s3] ls: ${S3_URI:-all buckets}"
    aws "${LS_ARGS[@]}"
    ;;

  # ── delete ───────────────────────────────────────────────────────────────────
  delete)
    require_field "bucket" "$BUCKET"
    require_field "prefix" "$PREFIX"

    S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    RM_ARGS=("${AWS_ARGS[@]}" s3 rm "$S3_URI")

    # If prefix ends with / treat as a folder and delete recursively
    [[ "$PREFIX" == */ ]] && RM_ARGS+=(--recursive)

    [ "$DRY_RUN" = "yes" ] && RM_ARGS+=(--dryrun)
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && RM_ARGS+=($EXTRA_FLAGS)

    echo "[s3] delete: ${S3_URI}"
    aws "${RM_ARGS[@]}"
    ;;

  # ── mb (make bucket) ─────────────────────────────────────────────────────────
  mb)
    require_field "bucket" "$BUCKET"

    MB_ARGS=("${AWS_ARGS[@]}" s3 mb "s3://${BUCKET}")
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && MB_ARGS+=($EXTRA_FLAGS)

    echo "[s3] mb: creating bucket s3://${BUCKET}"
    aws "${MB_ARGS[@]}"
    ;;

  # ── presign ──────────────────────────────────────────────────────────────────
  presign)
    require_field "bucket" "$BUCKET"
    require_field "prefix" "$PREFIX"

    S3_URI=$(s3_uri "$BUCKET" "$PREFIX")
    PRESIGN_ARGS=("${AWS_ARGS[@]}" s3 presign "$S3_URI" --expires-in "$PRESIGN_EXPIRES")
    # shellcheck disable=SC2206
    [ -n "$EXTRA_FLAGS" ] && PRESIGN_ARGS+=($EXTRA_FLAGS)

    echo "[s3] presign: ${S3_URI} (expires in ${PRESIGN_EXPIRES}s)"
    aws "${PRESIGN_ARGS[@]}"
    ;;

  *)
    echo "[s3] ERROR: unknown operation '${OPERATION}'"
    echo "{\"success\":false,\"error\":\"unknown operation: ${OPERATION}\"}"
    exit 1
    ;;
esac

EXIT_CODE=$?
END_TS=$(date +%s)
DURATION=$(( END_TS - START_TS ))

if [ $EXIT_CODE -eq 0 ]; then
  echo ""
  echo "{\"success\":true,\"operation\":\"${OPERATION}\",\"bucket\":\"${BUCKET}\",\"prefix\":\"${PREFIX}\",\"durationSeconds\":${DURATION}}"
else
  echo ""
  echo "{\"success\":false,\"operation\":\"${OPERATION}\",\"bucket\":\"${BUCKET}\",\"exitCode\":${EXIT_CODE},\"durationSeconds\":${DURATION}}"
  exit $EXIT_CODE
fi
