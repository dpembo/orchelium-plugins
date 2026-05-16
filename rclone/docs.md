# Rclone Plugin

Rclone is a command-line tool for syncing files between cloud storage providers, object stores, and local filesystems. It supports over 70 backends including S3, Google Drive, Dropbox, Backblaze B2, SFTP, and many more.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `sync` | Make destination identical to source (deletes extra files at destination) |
| `copy` | Copy new/changed files to destination without deleting anything |
| `move` | Move files from source to destination (deletes source after transfer) |
| `check` | Verify that source and destination files match |
| `ls` | List files in a remote or local path |
| `delete` | Delete files in a path (without removing the directory) |
| `purge` | Delete a directory and all its contents |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Operation** | Yes | — | Operation to perform |
| **Source** | Yes | sync, copy, move, check, ls, delete, purge | Source path or remote, e.g. `/local/path`, `s3:bucket/path`, `gdrive:Backups` |
| **Destination** | sync, copy, move, check | Destination path or remote |
| **Config File** | No | — | Path to a custom `rclone.conf` (defaults to `~/.config/rclone/rclone.conf`) |
| **Parallel Transfers** | No | — | Number of simultaneous file transfers (default: 4) |
| **Parallel Checkers** | No | — | Number of simultaneous file checkers (default: 8) |
| **Bandwidth Limit** | No | — | Transfer rate limit, e.g. `10M`, `1G`, `10M:off` (time-of-day schedule) |
| **Include Patterns** | No | — | Space-separated glob patterns to include |
| **Exclude Patterns** | No | — | Space-separated glob patterns to exclude |
| **Filter File** | No | — | Path to a file with include/exclude rules |
| **Use Checksum** | No | `no` | Compare by checksum instead of size+mtime |
| **Dry Run** | No | `no` | Simulate the operation without making changes |
| **Log Level** | No | `NOTICE` | Verbosity: `ERROR`, `NOTICE`, `INFO`, `DEBUG` |
| **Extra Flags** | No | — | Any additional rclone flags |

---

## Usage Examples

### Sync local directory to S3

```
Operation:    sync
Source:       /var/backups/databases
Destination:  s3:my-backup-bucket/databases
Transfers:    8
Log Level:    INFO
Extra Flags:  --s3-storage-class STANDARD_IA
```

### Copy to Google Drive

```
Operation:      copy
Source:         /home/dave/documents
Destination:    gdrive:Backups/documents
Transfers:      4
Exclude:        .cache/ *.tmp
```

### Mirror with bandwidth throttling

```
Operation:           sync
Source:              /data/media
Destination:         b2:my-b2-bucket/media
Bandwidth Limit:     50M
Exclude:             *.part .DS_Store
```

### Verify source and destination match

```
Operation:       check
Source:          /mnt/archive
Destination:     s3:my-archive-bucket/archive
Use Checksum:    yes
```

### List a remote path

```
Operation:    ls
Source:       s3:my-backup-bucket/databases
```

### Dry run to preview a sync

```
Operation:    sync
Source:       /var/www
Destination:  gdrive:WebBackups
Dry Run:      yes
Log Level:    INFO
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
