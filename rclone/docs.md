# Rclone Plugin

Rclone is a command-line tool for syncing files between cloud storage providers, object stores, and local filesystems. It supports over 70 backends including S3, Google Drive, Dropbox, Backblaze B2, SFTP, and many more.

---

## Common Parameters

All operations support optional parameters:

| Parameter | Description |
|-----------|-------------|
| **Config File** | Path to a custom `rclone.conf` (defaults to `~/.config/rclone/rclone.conf`) |
| **Parallel Transfers** | Number of simultaneous file transfers (default: 4) |
| **Parallel Checkers** | Number of simultaneous file checkers (default: 8) |
| **Bandwidth Limit** | Transfer rate limit, e.g. `10M`, `1G`, `10M:off` (time-of-day schedule) |
| **Include Patterns** | Space-separated glob patterns to include |
| **Exclude Patterns** | Space-separated glob patterns to exclude |
| **Filter File** | Path to a file with include/exclude rules |
| **Use Checksum** | Compare by checksum instead of size+mtime (`yes`/`no`) |
| **Dry Run** | Simulate the operation without making changes (`yes`/`no`) |
| **Log Level** | Verbosity: `ERROR`, `NOTICE`, `INFO`, `DEBUG` |
| **Extra Flags** | Any additional rclone flags |

---

## sync — Make Destination Identical to Source

Make destination identical to source (deletes extra files at destination).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Source path or remote, e.g. `/local/path`, `s3:bucket/path`, `gdrive:Backups` |
| **Destination** | Yes | Destination path or remote |

### Example

```
Operation:    sync
Source:       /var/backups/databases
Destination:  s3:my-backup-bucket/databases
Transfers:    8
Log Level:    INFO
Extra Flags:  --s3-storage-class STANDARD_IA
```

---

## copy — Copy New/Updated Files to Destination

Copy new/changed files to destination without deleting anything.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Source path or remote |
| **Destination** | Yes | Destination path or remote |

### Example

```
Operation:      copy
Source:         /home/dave/documents
Destination:    gdrive:Backups/documents
Transfers:      4
Exclude:        .cache/ *.tmp
```

---

## move — Move Files from Source to Destination

Move files from source to destination (deletes source after transfer).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Source path or remote |
| **Destination** | Yes | Destination path or remote |

### Example

```
Operation:    move
Source:       /data/media
Destination:  b2:my-b2-bucket/media
```

---

## check — Verify Source and Destination Match

Verify that source and destination files match without transferring.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Source path or remote |
| **Destination** | Yes | Destination path or remote |
| **Use Checksum** | No | Compare by checksum instead of size+mtime |

### Example

```
Operation:       check
Source:          /mnt/archive
Destination:     s3:my-archive-bucket/archive
Use Checksum:    yes
```

---

## ls — List Files in a Remote or Local Path

List files in a remote or local path.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Path or remote to list |

### Example

```
Operation:    ls
Source:       s3:my-backup-bucket/databases
```

---

## delete — Delete Files in a Path

Delete files in a path matching filters (without removing the directory).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Path or remote where files will be deleted |
| **Exclude Patterns** | No | Patterns to exclude from deletion |

### Example

```
Operation:    delete
Source:       s3:my-backup-bucket/old-backups
Exclude:      *.keep
```

---

## purge — Delete a Directory and All Its Contents

Delete a directory and all its contents.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source** | Yes | Path or remote directory to delete |

### Example

```
Operation:    purge
Source:       s3:my-backup-bucket/temp-data
```

---

## Remote Configuration

Remotes (e.g. `s3:`, `gdrive:`, `b2:`) must be configured in the rclone config file before use. Configure them once on the agent host:

```bash
rclone config
```

Or supply a pre-built `rclone.conf` and point the **Config File** field to it.

---

## Bandwidth Scheduling

The **Bandwidth Limit** field supports time-of-day schedules:

```
10M:off                 10 MB/s during working hours, off (unlimited) otherwise
09:00,512k 18:00,off    512 KB/s from 09:00, unlimited from 18:00
```

---

## Tips

- `sync` is destructive at the destination — use `copy` if you want to keep extra destination files.
- Use `--fast-list` in Extra Flags for S3/B2 to reduce API calls (helpful for large buckets).
- Combine `--delete-before` (Extra Flags) with `sync` so deleted files are removed before uploading, preserving destination space during the transfer.
- `--checksum` is more accurate but makes every file comparison slower; only use it when timestamp-based comparison is unreliable.
- Log files can be written with `--log-file /var/log/rclone.log` in Extra Flags.

---

## Requirements

- `rclone` installed on the agent host
- Remote(s) configured in `rclone.conf` on the agent
