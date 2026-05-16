#!/usr/bin/env bash
# Orchelium truenas plugin — run.sh
# Manages TrueNAS (CORE and SCALE) via the REST API v2.0.
#
# Operations: snapshot, delete-snapshot, list-snapshots,
#             replication-run, cloudsync-run, dataset-list, scrub
#
# Authentication: API key read from a file — never passed on the command line.

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
HOST=$(parse_field host)
API_KEY_FILE=$(parse_field api_key_file)
VERIFY_SSL=$(parse_field verify_ssl)
DATASET=$(parse_field dataset)
SNAPSHOT_NAME=$(parse_field snapshot_name)
RECURSIVE=$(parse_field recursive)
TASK_NAME=$(parse_field task_name)
POOL=$(parse_field pool)
TIMEOUT=$(parse_field timeout)

: "${OPERATION:=snapshot}"
: "${VERIFY_SSL:=yes}"
: "${RECURSIVE:=no}"
: "${SNAPSHOT_NAME:=auto-%Y-%m-%dT%H:%M:%S}"
: "${TIMEOUT:=30}"

# ── Validate required fields ────────────────────────────────────────────────────

if [ -z "$HOST" ]; then
  echo '[truenas] ERROR: host is required'
  echo '{"success":false,"error":"host is required"}'
  exit 1
fi

if [ -z "$API_KEY_FILE" ]; then
  echo '[truenas] ERROR: api_key_file is required'
  echo '{"success":false,"error":"api_key_file is required"}'
  exit 1
fi

if [ ! -f "$API_KEY_FILE" ]; then
  echo "[truenas] ERROR: API key file not found: $API_KEY_FILE"
  echo '{"success":false,"error":"API key file not found"}'
  exit 1
fi

# Read API key (strip trailing whitespace)
API_KEY=$(tr -d '[:space:]' < "$API_KEY_FILE")
if [ -z "$API_KEY" ]; then
  echo '[truenas] ERROR: API key file is empty'
  echo '{"success":false,"error":"API key file is empty"}'
  exit 1
fi

# ── Validate tool availability ──────────────────────────────────────────────────

if ! command -v curl &>/dev/null; then
  echo '[truenas] ERROR: curl is not installed on this agent'
  echo '{"success":false,"error":"curl not found in PATH"}'
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo '[truenas] ERROR: python3 is not installed on this agent'
  echo '{"success":false,"error":"python3 not found in PATH"}'
  exit 1
fi

# ── Build base URL ──────────────────────────────────────────────────────────────

# Normalise host: add https:// if no scheme present
if [[ "$HOST" != http://* ]] && [[ "$HOST" != https://* ]]; then
  HOST="https://${HOST}"
fi
# Strip trailing slash
HOST="${HOST%/}"
BASE_URL="${HOST}/api/v2.0"

# ── curl helper ─────────────────────────────────────────────────────────────────

CURL_OPTS=(
  --silent
  --show-error
  --max-time "$TIMEOUT"
  --header "Authorization: Bearer ${API_KEY}"
  --header "Content-Type: application/json"
)
[ "$VERIFY_SSL" = "no" ] && CURL_OPTS+=(--insecure)

# api_get <endpoint>
api_get() {
  curl "${CURL_OPTS[@]}" --request GET "${BASE_URL}${1}"
}

# api_post <endpoint> <json_body>
api_post() {
  curl "${CURL_OPTS[@]}" --request POST --data "$2" "${BASE_URL}${1}"
}

# api_delete <endpoint>
api_delete() {
  curl "${CURL_OPTS[@]}" --request DELETE "${BASE_URL}${1}"
}

# check_api_error <response_json> <operation_label>
# Returns 0 if response does not contain a top-level "error" or HTTP error, else exits 1
check_response() {
  local resp="$1"
  local label="$2"
  # If response is empty, that's an error
  if [ -z "$resp" ]; then
    echo "[truenas] ERROR: empty response from API for ${label}"
    echo "{\"success\":false,\"error\":\"empty API response for ${label}\"}"
    exit 1
  fi
  # If response contains a top-level "error" field, report it
  local err
  err=$(python3 -c "
import sys, json
try:
    d = json.loads(sys.stdin.read())
    if isinstance(d, dict) and 'error' in d:
        print(d['error'])
except:
    pass
" <<< "$resp" 2>/dev/null || true)
  if [ -n "$err" ]; then
    echo "[truenas] ERROR: API returned error for ${label}: ${err}"
    echo "{\"success\":false,\"error\":$(python3 -c "import json; print(json.dumps('${err//\'/}'))")}"
    exit 1
  fi
}

# ── Expand snapshot name date placeholders ──────────────────────────────────────

SNAPSHOT_NAME=$(date +"$SNAPSHOT_NAME")

# ── Operations ──────────────────────────────────────────────────────────────────

START_TS=$(date +%s)

case "$OPERATION" in

  # ── snapshot ────────────────────────────────────────────────────────────────
  snapshot)
    if [ -z "$DATASET" ]; then
      echo '[truenas] ERROR: dataset is required for snapshot'
      echo '{"success":false,"error":"dataset is required"}'
      exit 1
    fi

    RECURSIVE_BOOL="false"
    [ "$RECURSIVE" = "yes" ] && RECURSIVE_BOOL="true"

    BODY=$(python3 -c "
import json
print(json.dumps({
  'dataset': '${DATASET}',
  'name':    '${SNAPSHOT_NAME}',
  'recursive': ${RECURSIVE_BOOL}
}))
")
    echo "[truenas] Creating snapshot: ${DATASET}@${SNAPSHOT_NAME}"
    RESP=$(api_post "/zfs/snapshot" "$BODY")
    check_response "$RESP" "snapshot"
    echo "[truenas] Snapshot created: ${DATASET}@${SNAPSHOT_NAME}"
    echo "$RESP"
    ;;

  # ── delete-snapshot ──────────────────────────────────────────────────────────
  delete-snapshot)
    if [ -z "$DATASET" ] || [ -z "$SNAPSHOT_NAME" ]; then
      echo '[truenas] ERROR: dataset and snapshot_name are required for delete-snapshot'
      echo '{"success":false,"error":"dataset and snapshot_name are required"}'
      exit 1
    fi

    # URL-encode the @ in the snapshot id
    SNAP_ID=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${DATASET}@${SNAPSHOT_NAME}', safe=''))")
    echo "[truenas] Deleting snapshot: ${DATASET}@${SNAPSHOT_NAME}"
    RESP=$(api_delete "/zfs/snapshot/id/${SNAP_ID}")
    # A successful DELETE returns an empty body or the job ID — no error check needed for empty
    echo "[truenas] Delete request sent for: ${DATASET}@${SNAPSHOT_NAME}"
    [ -n "$RESP" ] && echo "$RESP"
    ;;

  # ── list-snapshots ───────────────────────────────────────────────────────────
  list-snapshots)
    QUERY=""
    if [ -n "$DATASET" ]; then
      QUERY="?dataset=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${DATASET}', safe=''))")"
    fi
    echo "[truenas] Listing snapshots${DATASET:+ for dataset: ${DATASET}}"
    RESP=$(api_get "/zfs/snapshot${QUERY}")
    check_response "$RESP" "list-snapshots"
    # Pretty-print the snapshot list
    python3 -c "
import sys, json
snaps = json.loads(sys.stdin.read())
if not isinstance(snaps, list):
    print(sys.stdin.read())
    sys.exit(0)
for s in snaps:
    print(s.get('id','?'))
print(f'\nTotal: {len(snaps)} snapshot(s)')
" <<< "$RESP"
    ;;

  # ── replication-run ──────────────────────────────────────────────────────────
  replication-run)
    if [ -z "$TASK_NAME" ]; then
      echo '[truenas] ERROR: task_name is required for replication-run'
      echo '{"success":false,"error":"task_name is required"}'
      exit 1
    fi

    echo "[truenas] Looking up replication task: ${TASK_NAME}"
    TASKS=$(api_get "/replication")
    check_response "$TASKS" "replication list"

    TASK_ID=$(python3 -c "
import sys, json
tasks = json.loads(sys.stdin.read())
name = '${TASK_NAME}'.lower()
for t in tasks:
    if t.get('name','').lower() == name:
        print(t['id'])
        break
" <<< "$TASKS")

    if [ -z "$TASK_ID" ]; then
      echo "[truenas] ERROR: replication task not found: ${TASK_NAME}"
      echo "{\"success\":false,\"error\":\"replication task not found: ${TASK_NAME}\"}"
      exit 1
    fi

    echo "[truenas] Running replication task '${TASK_NAME}' (id: ${TASK_ID})"
    BODY=$(python3 -c "import json; print(json.dumps({'id': int('${TASK_ID}')}))")
    RESP=$(api_post "/replication/run" "$BODY")
    check_response "$RESP" "replication-run"
    echo "[truenas] Replication task started (job id: ${RESP})"
    ;;

  # ── cloudsync-run ────────────────────────────────────────────────────────────
  cloudsync-run)
    if [ -z "$TASK_NAME" ]; then
      echo '[truenas] ERROR: task_name is required for cloudsync-run'
      echo '{"success":false,"error":"task_name is required"}'
      exit 1
    fi

    echo "[truenas] Looking up cloud sync task: ${TASK_NAME}"
    TASKS=$(api_get "/cloudsync")
    check_response "$TASKS" "cloudsync list"

    TASK_ID=$(python3 -c "
import sys, json
tasks = json.loads(sys.stdin.read())
name = '${TASK_NAME}'.lower()
for t in tasks:
    if t.get('description','').lower() == name:
        print(t['id'])
        break
" <<< "$TASKS")

    if [ -z "$TASK_ID" ]; then
      echo "[truenas] ERROR: cloud sync task not found: ${TASK_NAME}"
      echo "{\"success\":false,\"error\":\"cloud sync task not found: ${TASK_NAME}\"}"
      exit 1
    fi

    echo "[truenas] Running cloud sync task '${TASK_NAME}' (id: ${TASK_ID})"
    BODY=$(python3 -c "import json; print(json.dumps({'id': int('${TASK_ID}')}))")
    RESP=$(api_post "/cloudsync/run" "$BODY")
    check_response "$RESP" "cloudsync-run"
    echo "[truenas] Cloud sync task started (job id: ${RESP})"
    ;;

  # ── dataset-list ─────────────────────────────────────────────────────────────
  dataset-list)
    QUERY=""
    if [ -n "$POOL" ]; then
      QUERY="?pool=${POOL}"
    fi
    echo "[truenas] Listing datasets${POOL:+ in pool: ${POOL}}"
    RESP=$(api_get "/pool/dataset${QUERY}")
    check_response "$RESP" "dataset-list"
    python3 -c "
import sys, json
datasets = json.loads(sys.stdin.read())
if not isinstance(datasets, list):
    print(sys.stdin.read())
    sys.exit(0)
for d in datasets:
    used  = d.get('used',  {}).get('parsed', '?')
    avail = d.get('available', {}).get('parsed', '?')
    print(f\"{d.get('id','?'):<50}  used={used}  avail={avail}\")
print(f'\nTotal: {len(datasets)} dataset(s)')
" <<< "$RESP"
    ;;

  # ── scrub ────────────────────────────────────────────────────────────────────
  scrub)
    if [ -z "$POOL" ]; then
      echo '[truenas] ERROR: pool is required for scrub'
      echo '{"success":false,"error":"pool is required"}'
      exit 1
    fi

    BODY=$(python3 -c "import json; print(json.dumps({'name': '${POOL}', 'threshold': 0}))")
    echo "[truenas] Starting scrub on pool: ${POOL}"
    RESP=$(api_post "/pool/scrub" "$BODY")
    check_response "$RESP" "scrub"
    echo "[truenas] Scrub started on pool: ${POOL}"
    [ -n "$RESP" ] && echo "$RESP"
    ;;

  *)
    echo "[truenas] ERROR: unknown operation '${OPERATION}'"
    echo "{\"success\":false,\"error\":\"unknown operation: ${OPERATION}\"}"
    exit 1
    ;;
esac

END_TS=$(date +%s)
DURATION=$(( END_TS - START_TS ))
echo ""
echo "{\"success\":true,\"operation\":\"${OPERATION}\",\"host\":\"${HOST}\",\"durationSeconds\":${DURATION}}"
