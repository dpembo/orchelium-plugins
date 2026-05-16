# Borg Backup Plugin

BorgBackup is a deduplicating, compressing, encrypting backup program. It is extremely efficient for repositories that accumulate many incremental backups over time, as identical data is stored only once.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `create` | Create a new archive (snapshot) in the repository |
| `prune` | Remove archives that no longer match the retention policy |
| `check` | Verify repository and archive consistency |
| `list` | List all archives in the repository |
| `info` | Show detailed information about an archive |
| `compact` | Reclaim disk space freed by `prune` (Borg 1.2+) |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Repository** | Yes | All | Local path, `user@host:/path`, or `ssh://user@host:22/~/path` |
| **Archive Name** | create, info, check | Name or template; default `{hostname}-{now:%Y-%m-%dT%H:%M:%S}` |
| **Paths to Back Up** | create | Space-separated paths to include |
| **Passphrase File** | Yes | All | Path to a file containing the repository passphrase (empty for unencrypted) |
| **Compression** | No | create | Compression algorithm: `lz4`, `zstd`, `zlib`, `lzma`, `none` |
| **Exclude Patterns** | No | create | Space-separated glob patterns to skip |
| **Prune / Retention Policy** | prune | e.g. `--keep-daily 7 --keep-weekly 4 --keep-monthly 12` |
| **Archive Reference** | list, info, check | Archive name or `latest` |
| **Extra Flags** | No | All | Any additional Borg flags |

---

## Usage Examples

### Create a daily archive

```
Operation:         create
Repository:        /mnt/borg/myrepo
Archive Name:      {hostname}-{now:%Y-%m-%dT%H:%M:%S}
Paths:             /home /var/www /etc
Passphrase File:   /etc/borg/passphrase
Compression:       lz4
Exclude:           /home/*/.cache *.tmp
Extra Flags:       --stats
```

### Backup to a remote host over SSH

```
Operation:         create
Repository:        borguser@nas.local:/backups/myrepo
Archive Name:      webserver-{now:%Y-%m-%d}
Paths:             /var/www /etc/nginx
Passphrase File:   /etc/borg/passphrase
Compression:       zstd
```

### Apply retention policy

```
Operation:         prune
Repository:        /mnt/borg/myrepo
Passphrase File:   /etc/borg/passphrase
Prune Policy:      --keep-daily 7 --keep-weekly 4 --keep-monthly 6 --keep-yearly 2
Extra Flags:       --list --stats
```

### Compact repository (free disk space)

```
Operation:         compact
Repository:        /mnt/borg/myrepo
Passphrase File:   /etc/borg/passphrase
```

### List all archives

```
Operation:         list
Repository:        /mnt/borg/myrepo
Passphrase File:   /etc/borg/passphrase
```

### Check a specific archive

```
Operation:         check
Repository:        /mnt/borg/myrepo
Passphrase File:   /etc/borg/passphrase
Archive Ref:       latest
Extra Flags:       --verify-data
```

---

## Archive Name Templates

Borg supports several placeholders in archive names:

| Placeholder | Value |
|-------------|-------|
| `{hostname}` | Agent hostname |
| `{now}` | Current datetime |
| `{now:%Y-%m-%d}` | Date only |
| `{user}` | Running user |

---

## Compression Algorithms

| Algorithm | Speed | Ratio | Notes |
|-----------|-------|-------|-------|
| `none` | Fastest | 1:1 | Useful when network compression is active |
| `lz4` | Very fast | Good | Recommended default for most use cases |
| `zstd` | Fast | Excellent | Best balance of speed and ratio (Borg 1.1.4+) |
| `zlib` | Medium | Good | Classic gzip-compatible |
| `lzma` | Slow | Excellent | Best ratio but CPU-intensive |

---

## Tips

- Always run `prune` followed by `compact` in your workflow to actually reclaim disk space.
- Use `BORG_PASSPHRASE_FD` or a passphrase file — never hardcode passwords in scripts.
- Borg's deduplication is per-repository, so merging multiple sources into one repo maximises savings.
- Use `--exclude-caches` to automatically skip directories containing a `CACHEDIR.TAG` file.
- For remote repos, add `BORG_RSH='ssh -i /path/to/key'` to the agent environment if using a non-default key.

---

## Initialising a New Repository

Run once on the agent host before first use:

```bash
borg init --encryption=repokey /mnt/borg/myrepo
# or for remote:
borg init --encryption=repokey borguser@nas.local:/backups/myrepo
```

---

## Requirements

- `borgbackup` installed on the agent host
- Repository must be initialised before first use
