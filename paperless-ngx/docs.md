# Paperless-ngx Backup Plugin

Backup and export your Paperless-ngx document library via Docker. Manage maintenance mode, perform complete exports to timestamped directories, and compress backups in tar.gz or zip format. All operations run inside the Docker container to ensure data consistency.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Container** | Paperless-ngx container name or ID |

---

## maintenance-enable — Enable Maintenance Mode

Puts Paperless-ngx into maintenance mode, pausing background tasks and preventing new document imports. This ensures data consistency during exports.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container** | Yes | Paperless-ngx container name or ID |

### Example

```
Operation:   maintenance-enable
Container:   paperless
```

---

## maintenance-disable — Disable Maintenance Mode

Exits maintenance mode and resumes normal Paperless-ngx operations.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container** | Yes | Paperless-ngx container name or ID |

### Example

```
Operation:   maintenance-disable
Container:   paperless
```

---

## export — Export and Backup Documents

Exports all Paperless-ngx documents to a timestamped directory, compresses the backup, and optionally cleans up uncompressed files.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container** | Yes | Paperless-ngx container name or ID |
| **Target Path** | Yes | Directory where backups will be stored |
| **Compression Format** | No | Archive format: `tar.gz` (default) or `zip` |
| **Exclude Thumbnails** | No | Skip document thumbnails to reduce size (default: no) |
| **Compression Level** | No | 1 (fast), 6 (balanced), 9 (maximum) — default: 6 |
| **Keep Uncompressed** | No | Retain uncompressed files after archiving (default: no) |

### Example

```
Operation:          export
Container:          paperless
Target Path:        /mnt/backup-storage/paperless
Compression Format: tar.gz
Exclude Thumbnails: no
Compression Level:  6
Keep Uncompressed:  no
```

---

## Export Process

The export operation follows these steps:

1. Creates timestamped export directory in target location
2. Runs Paperless-ngx exporter inside container
3. Copies export from container to host
4. Compresses using tar.gz or zip
5. Cleans up uncompressed files (optional)

---

## Compression Formats

| Format | Compression | Size | Compatibility |
|--------|-------------|------|----------------|
| **tar.gz** | Better ratio | Smallest | Linux/macOS native; requires tar on Windows |
| **zip** | Good | Larger | Works on all platforms; built-in support |

---

## Compression Levels (tar.gz only)

| Level | Speed | Size | Use Case |
|-------|-------|------|----------|
| 1 | Fast | Largest | Quick backups, slow storage |
| 6 | Balanced | Medium | General backups (default) |
| 9 | Slow | Smallest | Archival, space-constrained |

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

## Recommended Workflow

For a complete backup cycle:

```
1. maintenance-enable
   Container: paperless

2. [Wait 30 seconds for in-progress tasks]

3. export
   Container:          paperless
   Target Path:        /mnt/backup-storage/paperless
   Compression Format: tar.gz

4. maintenance-disable
   Container: paperless
```

---

## Exclude Thumbnails

By default, exports include regenerated thumbnails. Set to `yes` to skip:
- Reduces export size by 20-40% (depending on document count)
- Thumbnails regenerate automatically on import
- Useful for frequent backups

---

## Troubleshooting

**Container Not Found**
- Verify container name/ID: `docker ps`
- Ensure container is running
- Check spelling exactly

**Docker Access Denied**
- Verify Docker is installed: `which docker`
- Verify agent user can run docker: `docker ps`
- Add user to docker group if needed: `usermod -aG docker $USER`

**Insufficient Disk Space**
- Export typically requires 1.5-2x the database size in temporary space
- Monitor with: `df -h`
- Increase storage before attempting export

**Permission Denied on Target Path**
- Verify target path exists: `mkdir -p /path/to/target`
- Check permissions: `ls -ld /path/to/target`
- Ensure Orchelium agent can write: `touch /path/to/target/test`

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

## Tips

- Use `maintenance-enable` before export to ensure data consistency
- Exports are timestamped automatically (`YYYYMMDD-HHMMSS`)
- Export time depends on document count and size (typically 5-30 minutes)
- Each export is independent — keep multiple historical backups
- Store archives in secure locations with restricted access: `chmod 700 /path/to/backups`

---

## Prerequisites

- Paperless-ngx running in a Docker container
- Orchelium agent with Docker access to the Paperless host
- Docker CLI installed on the agent
- Sufficient disk space for the export and compressed backup
- Appropriate permissions to run docker commands
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
