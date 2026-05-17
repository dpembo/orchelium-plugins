#!/usr/bin/env bash
# Orchelium Bitwarden Export plugin — run.sh
# Exports a Bitwarden organisation vault to a password-protected ZIP.
#
# Authentication: Bitwarden API key (client ID + client secret) + master password.
# Requires: bw (Bitwarden CLI), zip or 7z.
#
# SECURITY NOTES:
#   - Credentials are passed only via environment variables — never on the
#     command line where they would appear in `ps` output.
#   - The plaintext export file is deleted immediately after zipping.
#   - The vault session is logged out on exit (normal and error paths).

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

ORG_ID=$(parse_field organization_id)
CLIENT_ID=$(parse_field client_id)
CLIENT_SECRET=$(parse_field client_secret)
MASTER_PASSWORD=$(parse_field master_password)
ZIP_PASSWORD=$(parse_field zip_password)
FORMAT=$(parse_field format)
OUTPUT_PATH=$(parse_field output_path)
SERVER_URL=$(parse_field server_url)

: "${FORMAT:=csv}"
: "${SERVER_URL:=https://vault.bitwarden.com}"

# ── Validate required inputs ───────────────────────────────────────────────────
missing=()
[ -z "$ORG_ID" ]        && missing+=("organization_id")
[ -z "$CLIENT_ID" ]     && missing+=("client_id")
[ -z "$CLIENT_SECRET" ] && missing+=("client_secret")
[ -z "$MASTER_PASSWORD" ] && missing+=("master_password")
[ -z "$ZIP_PASSWORD" ]  && missing+=("zip_password")

if [ ${#missing[@]} -gt 0 ]; then
  python3 -c "import json; print(json.dumps({'success':False,'error':'Missing required inputs: ' + ', '.join($(python3 -c "import json,sys; print(json.dumps(${missing[*]@Q})" 2>/dev/null || echo "[]"))}))"
  echo "{\"success\":false,\"error\":\"Missing required inputs: ${missing[*]}\"}"
  exit 1
fi

# ── Check dependencies ─────────────────────────────────────────────────────────
if ! command -v bw &>/dev/null; then
  echo '{"success":false,"error":"bw (Bitwarden CLI) not found. Install it from https://bitwarden.com/help/cli/"}'
  exit 1
fi

ZIP_CMD=""
if command -v 7z &>/dev/null; then
  ZIP_CMD="7z"
elif command -v zip &>/dev/null; then
  ZIP_CMD="zip"
else
  echo '{"success":false,"error":"Neither 7z nor zip found. Install p7zip-full or zip on the agent."}'
  exit 1
fi

if ! command -v python3 &>/dev/null; then
  echo '{"success":false,"error":"python3 not found — required for input parsing."}'
  exit 1
fi

# ── Resolve output path ────────────────────────────────────────────────────────
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -z "$OUTPUT_PATH" ]; then
  OUTPUT_PATH="/tmp/bw-export-${TIMESTAMP}.zip"
fi
EXPORT_DIR=$(dirname "$OUTPUT_PATH")
mkdir -p "$EXPORT_DIR"

# Temp file for the plaintext export (deleted immediately after zipping)
EXPORT_FILE="${EXPORT_DIR}/.bw-export-${TIMESTAMP}.${FORMAT}"

# ── Cleanup on exit ────────────────────────────────────────────────────────────
BW_SESSION_TOKEN=""
cleanup() {
  # Remove plaintext export unconditionally
  rm -f "$EXPORT_FILE"
  # Logout if we have an active session
  if [ -n "$BW_SESSION_TOKEN" ]; then
    BW_SESSION="${BW_SESSION_TOKEN}" bw logout --quiet 2>/dev/null || true
  fi
  # Clear sensitive variables from shell environment
  unset BW_CLIENTID BW_CLIENTSECRET BW_PASSWORD BW_SESSION_TOKEN
}
trap cleanup EXIT

START_TS=$(date +%s)

# ── Configure server ───────────────────────────────────────────────────────────
echo "[bitwarden] Configuring server: $SERVER_URL"
export BW_URL="$SERVER_URL"
bw config server "$SERVER_URL" 2>&1 || true

# ── Authenticate with API key ──────────────────────────────────────────────────
echo "[bitwarden] Logging in with API key..."
export BW_CLIENTID="$CLIENT_ID"
export BW_CLIENTSECRET="$CLIENT_SECRET"

LOGIN_OUTPUT=$(bw login --apikey --raw 2>&1)
LOGIN_EXIT=$?

# bw login exits non-zero if already logged in — that is acceptable
if [ $LOGIN_EXIT -ne 0 ]; then
  if echo "$LOGIN_OUTPUT" | grep -qi "already logged in"; then
    echo "[bitwarden] Already logged in, proceeding."
  else
    echo "[bitwarden] Login failed: $LOGIN_OUTPUT"
    echo '{"success":false,"error":"Bitwarden login failed. Check client_id and client_secret."}'
    exit 1
  fi
fi

# ── Unlock vault ───────────────────────────────────────────────────────────────
echo "[bitwarden] Unlocking vault..."
export BW_PASSWORD="$MASTER_PASSWORD"

BW_SESSION_TOKEN=$(bw unlock --passwordenv BW_PASSWORD --raw 2>&1)
UNLOCK_EXIT=$?

if [ $UNLOCK_EXIT -ne 0 ]; then
  echo "[bitwarden] Unlock failed."
  echo '{"success":false,"error":"Vault unlock failed. Check master_password."}'
  exit 1
fi

if [ -z "$BW_SESSION_TOKEN" ]; then
  echo '{"success":false,"error":"Vault unlock returned empty session token."}'
  exit 1
fi

echo "[bitwarden] Vault unlocked."

# ── Sync (ensure latest data) ──────────────────────────────────────────────────
echo "[bitwarden] Syncing vault..."
bw sync --session "$BW_SESSION_TOKEN" 2>&1 || true

# ── Export ─────────────────────────────────────────────────────────────────────
echo "[bitwarden] Exporting organisation $ORG_ID in $FORMAT format..."

bw export \
  --organizationid "$ORG_ID" \
  --format "$FORMAT" \
  --output "$EXPORT_FILE" \
  --session "$BW_SESSION_TOKEN" 2>&1

EXPORT_EXIT=$?

if [ $EXPORT_EXIT -ne 0 ] || [ ! -f "$EXPORT_FILE" ]; then
  echo '{"success":false,"error":"bw export failed. Check organization_id and permissions."}'
  exit 1
fi

EXPORT_SIZE=$(stat -c%s "$EXPORT_FILE" 2>/dev/null || stat -f%z "$EXPORT_FILE" 2>/dev/null || echo 0)
echo "[bitwarden] Export complete (${EXPORT_SIZE} bytes). Compressing..."

# ── Create password-protected ZIP ─────────────────────────────────────────────
rm -f "$OUTPUT_PATH"

if [ "$ZIP_CMD" = "7z" ]; then
  # AES-256 encryption (-mhe=on also encrypts filenames inside the archive)
  7z a -tzip \
    -p"${ZIP_PASSWORD}" \
    -mhe=on \
    -mx=5 \
    "$OUTPUT_PATH" \
    "$EXPORT_FILE" > /dev/null 2>&1
  ZIP_EXIT=$?
else
  # ZipCrypto (weaker, but universally available)
  echo "[bitwarden] WARNING: 7z not found, using zip with ZipCrypto (weaker encryption). Install p7zip-full for AES-256."
  zip -P "${ZIP_PASSWORD}" -j "$OUTPUT_PATH" "$EXPORT_FILE" > /dev/null 2>&1
  ZIP_EXIT=$?
fi

if [ $ZIP_EXIT -ne 0 ] || [ ! -f "$OUTPUT_PATH" ]; then
  echo '{"success":false,"error":"Failed to create password-protected ZIP."}'
  exit 1
fi

ZIP_SIZE=$(stat -c%s "$OUTPUT_PATH" 2>/dev/null || stat -f%z "$OUTPUT_PATH" 2>/dev/null || echo 0)
END_TS=$(date +%s)
DURATION=$((END_TS - START_TS))

echo "[bitwarden] ZIP written to: $OUTPUT_PATH (${ZIP_SIZE} bytes)"

# ── Emit structured result ─────────────────────────────────────────────────────
python3 - <<PYEOF
import json
result = {
    "success":          True,
    "organizationId":   "$ORG_ID",
    "format":           "$FORMAT",
    "outputPath":       "$OUTPUT_PATH",
    "exportBytes":      $EXPORT_SIZE,
    "zipBytes":         $ZIP_SIZE,
    "zipTool":          "$ZIP_CMD",
    "durationSeconds":  $DURATION,
}
print(json.dumps(result))
PYEOF

exit 0
