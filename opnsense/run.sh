#!/usr/bin/env bash
# Orchelium opnsense plugin — run.sh
# Query and manage OPNsense firewall using REST API

set -uo pipefail
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

HOST=$(parse_field host)
API_KEY=$(parse_field api_key)
API_SECRET=$(parse_field api_secret)
VERIFY_SSL=$(parse_field verify_ssl)
OPERATION=$(parse_field operation)
BACKUP_ID=$(parse_field backup_id)
FIREWALL_FILTER=$(parse_field firewall_filter)
DIAGNOSTICS_LINES=$(parse_field diagnostics_lines)
OUTPUT_FORMAT=$(parse_field output_format)

: "${HOST:=localhost}"
: "${VERIFY_SSL:=no}"
: "${OPERATION:=system-status}"
: "${DIAGNOSTICS_LINES:=100}"
: "${OUTPUT_FORMAT:=json}"

# ── Validation ──────────────────────────────────────────────────────────────────

if [ -z "$API_KEY" ] || [ -z "$API_SECRET" ]; then
  echo '{"error":"API key and secret are required"}'
  exit 1
fi

if ! command -v curl &>/dev/null; then
  echo '{"error":"curl not found in PATH"}'
  exit 1
fi

# ── Build curl options ──────────────────────────────────────────────────────────

CURL_OPTS=(-s)
if [ "$VERIFY_SSL" != "yes" ]; then
  CURL_OPTS+=(-k)  # -k disables SSL verification for self-signed certs
fi

# ── Helper functions ────────────────────────────────────────────────────────────

opn_api_get() {
  local endpoint="$1"
  local url="https://${HOST}/api${endpoint}"
  
  curl "${CURL_OPTS[@]}" \
    -u "$API_KEY:$API_SECRET" \
    -H "Content-Type: application/json" \
    "$url"
}

opn_api_post() {
  local endpoint="$1"
  local data="${2:-{}}"
  local url="https://${HOST}/api${endpoint}"
  
  curl "${CURL_OPTS[@]}" \
    -X POST \
    -u "$API_KEY:$API_SECRET" \
    -H "Content-Type: application/json" \
    -d "$data" \
    "$url"
}

# Format output as CSV
json_to_csv() {
  python3 << 'PYEOF'
import sys, json, csv, io
try:
  data = json.load(sys.stdin)
  
  # Handle different data structures
  if isinstance(data, dict):
    if "rows" in data:
      # Has a "rows" field - use that
      rows = data["rows"]
    elif len(data) > 0 and all(isinstance(v, (dict, list)) for v in data.values()):
      # Dict with complex values - convert to key-value pairs
      writer = csv.writer(sys.stdout)
      writer.writerow(['Property', 'Value'])
      for k, v in data.items():
        if isinstance(v, (dict, list)):
          writer.writerow([k, json.dumps(v)])
        else:
          writer.writerow([k, str(v)])
      sys.exit(0)
    else:
      # Simple dict - treat as single row
      rows = [data]
  elif isinstance(data, list):
    rows = data
  else:
    rows = [data]
  
  if not rows:
    sys.exit(0)
  
  # Write CSV from rows
  if isinstance(rows[0], dict):
    # Get all unique keys
    all_keys = set()
    for row in rows:
      if isinstance(row, dict):
        all_keys.update(row.keys())
    
    fieldnames = sorted(all_keys)
    writer = csv.DictWriter(sys.stdout, fieldnames=fieldnames, extrasaction='ignore')
    writer.writeheader()
    writer.writerows(rows)
  else:
    writer = csv.writer(sys.stdout)
    writer.writerows([[r] for r in rows])
except Exception as e:
  print(f"Error converting to CSV: {e}", file=sys.stderr)
  sys.exit(1)
PYEOF
}

# ── Operations ──────────────────────────────────────────────────────────────────

case "$OPERATION" in
  
  backup-get)
    # List available backups
    RESULT=$(opn_api_get "/core/backup/backups/localhost")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  backup-download)
    # Download a backup configuration
    if [ -n "$BACKUP_ID" ]; then
      ENDPOINT="/core/backup/download/localhost/${BACKUP_ID}"
    else
      ENDPOINT="/core/backup/download/localhost"
    fi
    
    RESULT=$(opn_api_get "$ENDPOINT")
    
    # The result is XML config, save with timestamp
    FILENAME="opnsense-backup-$(date +%Y%m%d-%H%M%S).xml"
    echo "$RESULT" > "$FILENAME"
    
    echo "{\"success\":true,\"filename\":\"$FILENAME\",\"size\":$(stat -f%z "$FILENAME" 2>/dev/null || stat -c%s "$FILENAME" 2>/dev/null || echo 0)}"
    ;;
  
  firmware-status)
    # Get firmware status (version, pending updates, etc.)
    RESULT=$(opn_api_post "/core/firmware/status")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  firmware-get)
    # Get firmware configuration
    RESULT=$(opn_api_get "/core/firmware/get")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  firewall-rules-list)
    # List firewall filter rules
    if [ -n "$FIREWALL_FILTER" ]; then
      ENDPOINT="/firewall/filter/searchRule?current=1&rowCount=999&searchPhrase=${FIREWALL_FILTER}"
    else
      ENDPOINT="/firewall/filter/searchRule?current=1&rowCount=999"
    fi
    
    RESULT=$(opn_api_get "$ENDPOINT")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | python3 << 'PYEOF'
import sys, json, csv
data = json.load(sys.stdin)
writer = csv.writer(sys.stdout)
writer.writerow(['UUID', 'Description', 'Action', 'Protocol', 'Source', 'Destination', 'Interface', 'Enabled'])
for r in data.get('rows', []):
  writer.writerow([
    r.get('uuid', ''),
    r.get('description', 'N/A'),
    r.get('action', 'pass'),
    r.get('protocol', 'any'),
    r.get('source_net', 'any'),
    r.get('destination_net', 'any'),
    r.get('interface', 'any'),
    r.get('enabled', '1')
  ])
PYEOF
    else
      echo "$RESULT"
    fi
    ;;

  
  firewall-aliases-list)
    # List firewall aliases
    RESULT=$(opn_api_get "/firewall/alias/search_item?current=1&rowCount=999")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | python3 << 'PYEOF'
import sys, json, csv
data = json.load(sys.stdin)
writer = csv.writer(sys.stdout)
writer.writerow(['UUID', 'Name', 'Type', 'Description', 'Content'])
for r in data.get('rows', []):
  writer.writerow([
    r.get('uuid', ''),
    r.get('name', ''),
    r.get('type', ''),
    r.get('description', ''),
    r.get('content', '')
  ])
PYEOF
    else
      echo "$RESULT"
    fi
    ;;

  
  firewall-nat-list)
    # List all NAT rules (destination NAT, source NAT, 1:1 NAT)
    DNAT=$(opn_api_get "/firewall/d_nat/search_rule?current=1&rowCount=999")
    SNAT=$(opn_api_get "/firewall/source_nat/search_rule?current=1&rowCount=999")
    ONETONE=$(opn_api_get "/firewall/one_to_one/search_rule?current=1&rowCount=999")
    
    # Combine results using Python with arguments to avoid shell variable issues
    python3 - "$DNAT" "$SNAT" "$ONETONE" "$OUTPUT_FORMAT" << 'PYEOF'
import json, sys
try:
  dnat = json.loads(sys.argv[1]).get('rows', [])
  snat = json.loads(sys.argv[2]).get('rows', [])
  onetone = json.loads(sys.argv[3]).get('rows', [])
  output_format = sys.argv[4]
  
  result = {
    "destination_nat": dnat,
    "source_nat": snat,
    "one_to_one_nat": onetone,
    "total": len(dnat) + len(snat) + len(onetone)
  }
  
  if output_format == "csv":
    import csv
    writer = csv.writer(sys.stdout)
    writer.writerow(["Type", "UUID", "Description", "Source", "Destination", "Interface", "Enabled"])
    for rule in dnat:
      writer.writerow(["DNAT", rule.get('uuid',''), rule.get('description',''), rule.get('source',''), rule.get('target',''), rule.get('interface',''), rule.get('enabled','')])
    for rule in snat:
      writer.writerow(["SNAT", rule.get('uuid',''), rule.get('description',''), rule.get('source',''), rule.get('target',''), rule.get('interface',''), rule.get('enabled','')])
    for rule in onetone:
      writer.writerow(["1:1", rule.get('uuid',''), rule.get('description',''), rule.get('source',''), rule.get('target',''), rule.get('interface',''), rule.get('enabled','')])
  else:
    print(json.dumps(result, indent=2))
except Exception as e:
  print(json.dumps({"error": str(e)}))
  sys.exit(1)
PYEOF
    ;;


  
  firewall-stats)
    # Get firewall statistics
    RESULT=$(opn_api_get "/diagnostics/firewall/stats")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  diagnostics-firewall-log)
    # Get firewall logs
    RESULT=$(opn_api_post "/diagnostics/firewall/log?limit=${DIAGNOSTICS_LINES}")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  diagnostics-system-info)
    # Get system information (hostname, version, uptime, etc.)
    RESULT=$(opn_api_post "/diagnostics/system/system_information")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | python3 << 'PYEOF'
import sys, json, csv
data = json.load(sys.stdin)
writer = csv.writer(sys.stdout)
writer.writerow(['Property', 'Value'])
for k, v in data.items():
  if isinstance(v, (dict, list)):
    writer.writerow([k, json.dumps(v)])
  else:
    writer.writerow([k, str(v)])
PYEOF
    else
      echo "$RESULT"
    fi
    ;;
  
  diagnostics-system-resources)
    # Get system resources (CPU, memory, disk, swap)
    # Note: Some diagnostics endpoints work better as POST even if documented as GET
    RESULT=$(opn_api_post "/diagnostics/system/system_resources")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  diagnostics-interface-stats)
    # Get network interface statistics
    RESULT=$(opn_api_post "/diagnostics/interface/get_interface_statistics")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | json_to_csv
    else
      echo "$RESULT"
    fi
    ;;
  
  system-status)
    # Get core system status
    RESULT=$(opn_api_get "/core/system/status")
    if [ "$OUTPUT_FORMAT" = "csv" ]; then
      echo "$RESULT" | python3 << 'PYEOF'
import sys, json, csv
data = json.load(sys.stdin)
writer = csv.writer(sys.stdout)
writer.writerow(['Property', 'Value'])
for k, v in data.items():
  if isinstance(v, (dict, list)):
    writer.writerow([k, json.dumps(v)])
  else:
    writer.writerow([k, str(v)])
PYEOF
    else
      echo "$RESULT"
    fi
    ;;
  
  *)
    echo "{\"error\":\"Unknown operation: $OPERATION\"}"
    exit 1
    ;;
esac
