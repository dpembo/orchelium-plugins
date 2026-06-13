# Paperless-ngx Backup Plugin

Backup and export your Paperless-ngx document library via Docker.

Manage maintenance mode, perform complete exports to timestamped directories, and compress backups in tar.gz or zip format. All operations run inside the Docker container to ensure data consistency.

---

## Prerequisites

- Paperless-ngx running in a Docker container
- Orchelium agent with Docker access to the Paperless host
- Docker CLI installed on the agent
- Sufficient disk space for the export and compressed backup
- Appropriate permissions to run docker commands

---

## Parameters

### Required Parameters

| Parameter | Description |
|-----------|-------------|
| **Container** | Paperless-ngx container name or ID |
| **Operation** | `maintenance-enable`, `maintenance-disable`, or `export` |

### Export-Specific Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| **Target Path** | string | required | Directory where backups will be stored |
| **Compression Format** | select | tar.gz | Archive format: `tar.gz` or `zip` |
| **Exclude Thumbnails** | boolean | false | Skip document thumbnails to reduce size |
| **Compression Level** | select | 6 | Level 1 (fast), 6 (balanced), 9 (maximum) |
| **Keep Uncompressed** | boolean | false | Retain uncompressed files after archiving |

---

## Operations

### `maintenance-enable` — Enable Maintenance Mode

Puts Paperless-ngx into maintenance mode, pausing background tasks and preventing new document imports. This ensures data consistency during exports.

**Response:**
```json
{
  "success": true,
  "message": "Maintenance mode enabled"
}
```

**Usage:**
```bash
orchelium run paperless-ngx \
  --container paperless \
  --operation maintenance-enable
```

---

### `maintenance-disable` — Disable Maintenance Mode

Exits maintenance mode and resumes normal Paperless-ngx operations.

**Response:**
```json
{
  "success": true,
  "message": "Maintenance mode disabled"
}
```

**Usage:**
```bash
orchelium run paperless-ngx \
  --container paperless \
  --operation maintenance-disable
```

---

### `export` — Export and Backup Documents

Exports all Paperless-ngx documents to a timestamped directory, compresses the backup, and optionally cleans up uncompressed files.

**Process:**
1. Creates timestamped export directory in target location
2. Runs Paperless-ngx exporter inside container
3. Copies export from container to host
4. Compresses using tar.gz or zip
5. Cleans up uncompressed files (optional)

**Response:**
```json
{
  "success": true,
  "archive": "/backups/paperless/paperless-export-20260613-125340.tar.gz",
  "size": 2048576000,
  "format": "tar.gz",
  "timestamp": "20260613-125340"
}
```

**Usage:**
```bash
orchelium run paperless-ngx \
  --container paperless \
  --operation export \
  --target_path /backups/paperless \
  --compression_format tar.gz \
  --exclude_thumbnails false
```

---

## Recommended Workflow

For a complete backup cycle:

```bash
# 1. Enable maintenance mode (stops new imports, pauses tasks)
orchelium run paperless-ngx \
  --container paperless \
  --operation maintenance-enable

# 2. Wait a moment for any in-progress operations to finish
sleep 30

# 3. Export and compress documents
orchelium run paperless-ngx \
  --container paperless \
  --operation export \
  --target_path /mnt/backup-storage/paperless \
  --compression_format tar.gz

# 4. Disable maintenance mode (resume normal operations)
orchelium run paperless-ngx \
  --container paperless \
  --operation maintenance-disable
```

---

## Archive Contents

The exported archive contains:

```
paperless-export-20260613-125340/
├── documents/
│   ├── Document 1.pdf
│   ├── Document 2.pdf
│   └── ...
├── documents.json
├── config.json
├── metadata/
│   ├── thumbs/
│   └── ...
└── manifest.json
```

---

## Export Options

### Compression Formats

**tar.gz** (default)
- Better compression ratio
- Smaller archive size
- Linux/macOS native support
- Requires tar utility on Windows

**zip**
- Better compatibility
- Works on all platforms
- Larger file size
- Built-in support on most systems

### Compression Levels (tar.gz only)

| Level | Speed | Compression | Use Case |
|-------|-------|-------------|----------|
| 1 | Fast | Lowest | Quick backups, slow storage |
| 6 | Balanced | Good | General backups (default) |
| 9 | Slow | Maximum | Archival, space-constrained |

### Exclude Thumbnails

By default, exports include regenerated thumbnails. Set to `true` to skip:
- Reduces export size by 20-40% (depending on document count)
- Thumbnails regenerate automatically on import
- Useful for frequent backups

---

## Troubleshooting

### Container Not Found
```
{"error":"container not running: paperless"}
```
- Verify container name/ID: `docker ps`
- Ensure container is running
- Check spelling exactly

### Docker Access Denied
```
{"error":"docker is not installed on this agent"}
```
- Verify Docker is installed: `which docker`
- Verify agent user can run docker: `docker ps`
- Add user to docker group if needed: `usermod -aG docker $USER`

### Insufficient Disk Space
- Export typically requires 1.5-2x the database size in temporary space
- Monitor with: `df -h`
- Increase storage before attempting export

### Export Directory Permission Denied
```
{"error":"Failed to create export directory: /backups/paperless"}
```
- Verify target path exists: `mkdir -p /backups/paperless`
- Check permissions: `ls -ld /backups/paperless`
- Ensure Orchelium agent can write: `touch /backups/paperless/test` && `rm /backups/paperless/test`

### Container Export Copy Failed
- Ensure container has disk space for temporary export
- Check container logs: `docker logs paperless`
- Verify docker socket is accessible

---

## Restoring from Backup

To restore from a tar.gz backup:

```bash
# Extract to temporary location
mkdir /tmp/paperless-restore
tar -xzf /path/to/paperless-export-20260613-125340.tar.gz -C /tmp/paperless-restore

# Copy to Paperless import directory
docker cp /tmp/paperless-restore/paperless-export-20260613-125340/. paperless:/import/

# Import via Paperless UI or CLI
docker exec paperless python /app/manage.py document_importer /import
```

---

## File Structure

The plugin creates the following structure:

```
/target_path/
├── paperless-export-20260613-125340.tar.gz
├── paperless-export-20260612-100000.tar.gz
├── paperless-export-20260611-100000.tar.gz
└── ...
```

Each export is timestamped (`YYYYMMDD-HHMMSS`) and can be easily identified and managed.

---

## Performance Notes

- Export time depends on document count and size (typically 5-30 minutes)
- Compression time varies: 1 (fast) to 9 (slow) compression levels
- Network overhead if agent and container are on different hosts
- Monitor Docker daemon load during export with: `docker stats`

---

## Security Considerations

- Archives contain sensitive document metadata and content
- Store backups in secure locations
- Use encryption for archival storage
- Restrict access to backup directories: `chmod 700 /backups/paperless`
- Consider separate storage for archives on different systems

---

## Version History

**1.0.0** (2026-06-13)
- Initial release
- Maintenance mode enable/disable
- Full export with compression (tar.gz and zip)
- Timestamped export directories
- Optional uncompressed file retention
- Thumbnail exclusion option
