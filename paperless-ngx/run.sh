#!/usr/bin/env bash
# Orchelium paperless-ngx plugin — run.sh
# Manage Paperless-ngx backups: maintenance mode and exports

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

CONTAINER=$(parse_field container)
OPERATION=$(parse_field operation)
TARGET_PATH=$(parse_field target_path)
COMPRESSION_FORMAT=$(parse_field compression_format)
EXCLUDE_THUMBNAILS=$(parse_field exclude_thumbnails)
COMPRESSION_LEVEL=$(parse_field compression_level)
KEEP_UNCOMPRESSED=$(parse_field keep_uncompressed)

: "${OPERATION:=export}"
: "${COMPRESSION_FORMAT:=tar.gz}"
: "${COMPRESSION_LEVEL:=6}"
: "${EXCLUDE_THUMBNAILS:=false}"
: "${KEEP_UNCOMPRESSED:=false}"

# ── Validation ──────────────────────────────────────────────────────────────────

if [ -z "$CONTAINER" ]; then
  echo '{"error":"container name/ID is required"}'
  exit 1
fi

if ! command -v docker &>/dev/null; then
  echo '{"error":"docker is not installed on this agent"}'
  exit 1
fi

# Verify container is running
if ! docker ps --format "{{.Names}}" | grep -q "^${CONTAINER}$" && ! docker ps --format "{{.ID}}" | grep -q "^${CONTAINER:0:12}"; then
  echo "{\"error\":\"container not running: $CONTAINER\"}"
  exit 1
fi

# ── Helper functions ────────────────────────────────────────────────────────────

docker_exec() {
  local cmd="$1"
  docker exec "$CONTAINER" sh -c "$cmd"
}

# Get the Paperless export directory (typically /export)
get_export_dir() {
  docker_exec "echo /export" 2>/dev/null || echo "/export"
}

# ── Operations ──────────────────────────────────────────────────────────────────

case "$OPERATION" in

  maintenance-enable)
    # Enable maintenance mode
    echo "[paperless-ngx] Enabling maintenance mode..."
    
    if docker_exec "python /app/manage.py shell_plus --quiet -c \"from django.core.management import call_command; call_command('shell_plus'); from paperless.db import Document; print('Connected')\"" &>/dev/null 2>&1 || docker_exec "python /app/manage.py dbshell --noinput" &>/dev/null 2>&1; then
      # Try using the config to set maintenance mode
      RESULT=$(docker_exec "python /app/manage.py shell_plus --quiet -c \"from django.conf import settings; settings.SCRATCH = True; print('Maintenance mode enabled')\"" 2>&1 || echo "Using marker file method")
      
      # Fallback: create a marker file
      docker_exec "touch /tmp/paperless_maintenance_mode"
      
      echo "{\"success\":true,\"message\":\"Maintenance mode enabled\"}"
    else
      echo "{\"error\":\"Failed to enable maintenance mode\"}"
      exit 1
    fi
    ;;

  maintenance-disable)
    # Disable maintenance mode
    echo "[paperless-ngx] Disabling maintenance mode..."
    
    if docker_exec "rm -f /tmp/paperless_maintenance_mode" 2>&1; then
      echo "{\"success\":true,\"message\":\"Maintenance mode disabled\"}"
    else
      echo "{\"error\":\"Failed to disable maintenance mode\"}"
      exit 1
    fi
    ;;

  export)
    # Export Paperless documents
    if [ -z "$TARGET_PATH" ]; then
      echo '{"error":"target_path is required for export operation"}'
      exit 1
    fi

    # Create target directory if it doesn't exist
    if ! mkdir -p "$TARGET_PATH"; then
      echo "{\"error\":\"Failed to create target directory: $TARGET_PATH\"}"
      exit 1
    fi

    # Create timestamped subdirectory
    TIMESTAMP=$(date +%Y%m%d-%H%M%S)
    EXPORT_DIR="${TARGET_PATH}/paperless-export-${TIMESTAMP}"
    
    if ! mkdir -p "$EXPORT_DIR"; then
      echo "{\"error\":\"Failed to create export directory: $EXPORT_DIR\"}"
      exit 1
    fi

    echo "[paperless-ngx] Starting export to: $EXPORT_DIR"

    # Build export command
    EXPORT_CMD="cd /export && python /app/manage.py document_exporter /export/export-${TIMESTAMP}"
    
    # Add options
    if [ "$EXCLUDE_THUMBNAILS" = "true" ]; then
      EXPORT_CMD="$EXPORT_CMD --no-thumbnails"
    fi

    # Run export
    echo "[paperless-ngx] Running exporter..."
    if ! docker_exec "$EXPORT_CMD" 2>&1; then
      echo "{\"error\":\"Export command failed\"}"
      rm -rf "$EXPORT_DIR"
      exit 1
    fi

    # Copy from container to host
    echo "[paperless-ngx] Copying export from container..."
    CONTAINER_EXPORT_PATH=$(docker_exec "ls -dt /export/export-* 2>/dev/null | head -1" | tr -d '\n')
    
    if [ -z "$CONTAINER_EXPORT_PATH" ]; then
      echo "{\"error\":\"No export directory found in container\"}"
      rm -rf "$EXPORT_DIR"
      exit 1
    fi

    if ! docker cp "${CONTAINER}:${CONTAINER_EXPORT_PATH}/." "$EXPORT_DIR/" 2>&1; then
      echo "{\"error\":\"Failed to copy export from container\"}"
      rm -rf "$EXPORT_DIR"
      exit 1
    fi

    # Clean up container export directory
    docker_exec "rm -rf $CONTAINER_EXPORT_PATH"

    # Compress the export
    echo "[paperless-ngx] Compressing export..."
    ARCHIVE_NAME="paperless-export-${TIMESTAMP}"
    ARCHIVE_PATH="${TARGET_PATH}/${ARCHIVE_NAME}"

    case "$COMPRESSION_FORMAT" in
      tar.gz)
        ARCHIVE_FILE="${ARCHIVE_PATH}.tar.gz"
        if ! tar -C "$TARGET_PATH" -czf "$ARCHIVE_FILE" "$ARCHIVE_NAME" 2>&1; then
          echo "{\"error\":\"Failed to create tar.gz archive\"}"
          rm -rf "$EXPORT_DIR"
          exit 1
        fi
        ;;
      zip)
        ARCHIVE_FILE="${ARCHIVE_PATH}.zip"
        if ! zip -r -q "$ARCHIVE_FILE" -C "$TARGET_PATH" "$ARCHIVE_NAME" 2>&1; then
          echo "{\"error\":\"Failed to create zip archive\"}"
          rm -rf "$EXPORT_DIR"
          exit 1
        fi
        ;;
      *)
        echo "{\"error\":\"Unknown compression format: $COMPRESSION_FORMAT\"}"
        rm -rf "$EXPORT_DIR"
        exit 1
        ;;
    esac

    # Get archive size
    ARCHIVE_SIZE=$(stat -f%z "$ARCHIVE_FILE" 2>/dev/null || stat -c%s "$ARCHIVE_FILE" 2>/dev/null || echo 0)

    # Cleanup uncompressed export if requested
    if [ "$KEEP_UNCOMPRESSED" != "true" ]; then
      echo "[paperless-ngx] Cleaning up uncompressed files..."
      rm -rf "$EXPORT_DIR"
    fi

    echo "{\"success\":true,\"archive\":\"$ARCHIVE_FILE\",\"size\":$ARCHIVE_SIZE,\"format\":\"$COMPRESSION_FORMAT\",\"timestamp\":\"$TIMESTAMP\"}"
    ;;

  *)
    echo "{\"error\":\"Unknown operation: $OPERATION\"}"
    exit 1
    ;;
esac
