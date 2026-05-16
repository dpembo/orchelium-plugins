# Rsync Plugin

Rsync is a fast, versatile file-copying and synchronisation tool. It transfers only the differences between source and destination, making it ideal for incremental backups, remote file mirroring, and deployment workflows.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `sync` | Synchronise source to destination (transfers only changed/new files) |
| `check` | Dry-run comparison — shows what *would* change without transferring anything |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `sync` | The operation to perform |
| **Source** | Yes | — | Source path: local (`/path/`) or remote (`user@host:/path/`) |
| **Destination** | Yes | — | Destination path: local or remote |
| **Options** | No | `-avz` | rsync flags, e.g. `-avz --delete --progress` |
| **SSH Key Path** | No | — | Path to a private key for SSH-based transfers |
| **Bandwidth Limit (KB/s)** | No | — | Throttle the transfer rate; `0` means unlimited |

---

## Usage Examples

### Daily local backup with deletion

```
Operation:   sync
Source:      /var/www/html/
Destination: /mnt/backup/html/
Options:     -avz --delete
```

### Remote backup over SSH with a custom key

```
Operation:   sync
Source:      /home/dave/
Destination: backupuser@192.168.1.50:/mnt/nas/dave/
Options:     -avz --delete --exclude='.cache/'
SSH Key:     /root/.ssh/id_ed25519
```

### Bandwidth-limited off-site sync

```
Operation:          sync
Source:             /var/lib/pgsql/
Destination:        remoteuser@offsite.example.com:/backups/pgsql/
Options:            -az --delete
Bandwidth Limit:    5120
```

### Verify what would change (dry run)

```
Operation:   check
Source:      /data/
Destination: /mnt/backup/data/
Options:     -avz --delete
```

---

## Common Options Reference

| Flag | Effect |
|------|--------|
| `-a` | Archive mode (preserves permissions, timestamps, symlinks, owner) |
| `-v` | Verbose output |
| `-z` | Compress data during transfer |
| `--delete` | Remove destination files that no longer exist in source |
| `--exclude='pattern'` | Skip files matching the pattern |
| `--checksum` | Compare by checksum instead of size+timestamp (slower, more accurate) |
| `--progress` | Show per-file progress |
| `--dry-run` | Simulate without making changes (same as `check` operation) |

---

## Tips

- Always end directory paths with a trailing `/` to copy the **contents** rather than the directory itself.
- Add `--exclude='.cache/' --exclude='*.tmp'` to skip transient files.
- Use `--checksum` for forensic-level accuracy when clock drift may affect timestamps.
- Combine `--delete` with `--backup --backup-dir=/mnt/deleted/` to keep a copy of removed files.
- The `check` operation is non-destructive — run it before every first-time `sync` to audit the change set.

---

## Requirements

- `rsync` installed on the agent host
- SSH access and appropriate credentials for remote transfers
