#!/usr/bin/env bash
# Orchelium proxmox-backup plugin — run.sh
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

VMID=$(parse_field vmid)
MODE=$(parse_field mode)
COMPRESS=$(parse_field compress)
STORAGE=$(parse_field storage)
DUMPDIR=$(parse_field dumpdir)
PRUNE=$(parse_field prune_backups)
MAILTO=$(parse_field mailto)
NOTES=$(parse_field notes_template)
EXTRA_FLAGS=$(parse_field extra_flags)

# Apply defaults
: "${MODE:=snapshot}"
: "${COMPRESS:=zstd}"

# ── Validate ────────────────────────────────────────────────────────────────────

if [ -z "$VMID" ]; then
  echo '{"success":false,"error":"vmid is required"}'
  exit 1
fi

if ! command -v vzdump &>/dev/null; then
  echo "[proxmox-backup] ERROR: vzdump not found — this plugin must run on a Proxmox node"
  echo '{"success":false,"error":"vzdump not found in PATH"}'
  exit 1
fi

if [ -z "$STORAGE" ] && [ -z "$DUMPDIR" ]; then
  echo '[proxmox-backup] ERROR: either storage or dumpdir must be set'
  echo '{"success":false,"error":"storage or dumpdir is required"}'
  exit 1
fi

# When dumpdir is specified validate it exists
if [ -z "$STORAGE" ] && [ ! -d "$DUMPDIR" ]; then
  echo "[proxmox-backup] ERROR: dumpdir does not exist: $DUMPDIR"
  echo '{"success":false,"error":"dumpdir does not exist"}'
  exit 1
fi

# ── Build vzdump command ────────────────────────────────────────────────────────

VZDUMP_ARGS=()

# VM ID(s) — 'all' becomes --all flag; otherwise pass each ID individually
if [ "$VMID" = "all" ]; then
  VZDUMP_ARGS+=("--all")
else
  # Support space-separated list of IDs
  read -ra VMID_ARRAY <<< "$VMID"
  VZDUMP_ARGS+=("${VMID_ARRAY[@]}")
fi

VZDUMP_ARGS+=("--mode" "$MODE")
VZDUMP_ARGS+=("--compress" "$COMPRESS")

if [ -n "$STORAGE" ]; then
  VZDUMP_ARGS+=("--storage" "$STORAGE")
else
  VZDUMP_ARGS+=("--dumpdir" "$DUMPDIR")
fi

if [ -n "$PRUNE" ]; then
  VZDUMP_ARGS+=("--prune-backups" "$PRUNE")
fi

if [ -n "$MAILTO" ]; then
  VZDUMP_ARGS+=("--mailto" "$MAILTO")
fi

if [ -n "$NOTES" ]; then
  VZDUMP_ARGS+=("--notes-template" "$NOTES")
fi

if [ -n "$EXTRA_FLAGS" ]; then
  read -ra EXTRA_ARRAY <<< "$EXTRA_FLAGS"
  VZDUMP_ARGS+=("${EXTRA_ARRAY[@]}")
fi

# ── Execute ─────────────────────────────────────────────────────────────────────

echo "[proxmox-backup] Running: vzdump ${VZDUMP_ARGS[*]}"

START_TS=$(date +%s)
LOG_FILE=$(mktemp)

# Stream output live while also saving it for post-run parsing.
if command -v stdbuf >/dev/null 2>&1; then
  stdbuf -oL -eL vzdump "${VZDUMP_ARGS[@]}" | tee "$LOG_FILE"
else
  vzdump "${VZDUMP_ARGS[@]}" | tee "$LOG_FILE"
fi
EXIT_CODE=${PIPESTATUS[0]}
DURATION=$(( $(date +%s) - START_TS ))

VZDUMP_OUTPUT=$(cat "$LOG_FILE")
rm -f "$LOG_FILE"

if [ "$EXIT_CODE" -ne 0 ]; then
  echo "[proxmox-backup] FAILED with exit code $EXIT_CODE"
fi

# ── Parse vzdump output ─────────────────────────────────────────────────────────
# vzdump logs lines like:
#   INFO: archive transfer rate: 94.42 MB/s
#   INFO: Finished Backup of VM 100 (00:01:23) (11.37 GiB)
#   ERROR: Backup of VM 100 failed - ...

python3 - <<PYEOF
import re, json, sys

raw      = """$VZDUMP_OUTPUT"""
vmid     = "$VMID"
mode     = "$MODE"
compress = "$COMPRESS"
exit_code = $EXIT_CODE
duration  = $DURATION

vms_ok   = re.findall(r'Finished Backup of VM (\d+)', raw)
vms_fail = re.findall(r'Backup of VM (\d+) failed', raw)

# Parse backup size: "Finished Backup of VM 100 (00:01:23) (11.37 GiB)"
sizes = re.findall(r'Finished Backup of VM \d+ \([^)]+\) \(([^)]+)\)', raw)

result = {
    "success":        exit_code == 0,
    "exitCode":       exit_code,
    "vmid":           vmid,
    "mode":           mode,
    "compress":       compress,
    "durationSeconds": duration,
    "vmsCompleted":   vms_ok,
    "vmsFailed":      vms_fail,
    "backupSizes":    sizes,
}

print(json.dumps(result))
PYEOF

exit $EXIT_CODE
