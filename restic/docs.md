# Restic Backup Plugin

Restic is a modern, fast, secure backup program that supports deduplication and encryption. It can store backups in local directories, SFTP servers, S3, Backblaze B2, and many other backends.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Repository** | Repository URL: local path, `sftp:user@host:/path`, `s3:s3.amazonaws.com/bucket`, etc. |
| **Password File** | Path to a file containing the repository password |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Extra Flags** | Any additional restic flags |

---

## backup — Create a New Snapshot

Create a new snapshot of the specified paths.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Repository** | Yes | Repository URL |
| **Password File** | Yes | Path to a file containing the repository password |
| **Paths to Back Up** | Yes | Space-separated list of paths to include in the snapshot |
| **Tags** | No | Space-separated tags for the snapshot |
| **Exclude Patterns** | No | Space-separated glob patterns to exclude |
| **Extra Flags** | No | Additional restic flags |

### Example

```
Operation:        backup
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
Paths:            /home/dave /var/www
Tags:             daily web
Exclude:          *.log .cache
```

---

## forget — Apply a Retention Policy

Apply a retention policy and remove old snapshots.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Repository** | Yes | Repository URL |
| **Password File** | Yes | Path to a file containing the repository password |
| **Forget / Retention Policy** | Yes | Flags like `--keep-daily 7 --keep-weekly 4 --keep-monthly 12` |
| **Tags** | No | Space-separated tags to filter snapshots |
| **Extra Flags** | No | Additional flags (e.g. `--prune`) |

### Example

```
Operation:           forget
Repository:          /mnt/backup/restic-repo
Password File:       /etc/restic/password
Forget Policy:       --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
Tags:                daily
```

---

## check — Verify Repository Integrity

Verify the repository integrity.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Repository** | Yes | Repository URL |
| **Password File** | Yes | Path to a file containing the repository password |
| **Extra Flags** | No | Additional flags (e.g. `--read-data-subset=10%`) |

### Example

```
Operation:        check
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
Extra Flags:      --read-data-subset=10%
```

---

## snapshots — List All Snapshots

List all snapshots in the repository.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Repository** | Yes | Repository URL |
| **Password File** | Yes | Path to a file containing the repository password |
| **Extra Flags** | No | Additional restic flags |

### Example

```
Operation:        snapshots
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
```

---

## restore — Restore a Snapshot

Restore a snapshot to a target directory.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Repository** | Yes | Repository URL |
| **Password File** | Yes | Path to a file containing the repository password |
| **Snapshot ID** | No | The snapshot ID to restore (default: `latest`) |
| **Restore Target** | Yes | Directory to restore files into |
| **Extra Flags** | No | Additional restic flags |

### Example

```
Operation:           restore
Repository:          /mnt/backup/restic-repo
Password File:       /etc/restic/password
Snapshot ID:         latest
Restore Target:      /tmp/restore
```

---

## Password File Format

The password file should contain a single line with the repository password:

```
mysecretpassword
```

Set permissions to `600`:

```bash
chmod 600 /etc/restic/password
```

---

## Initialising a New Repository

Before backing up, you must initialise the repository once on the agent host:

```bash
restic -r /mnt/backup/restic-repo --password-file /etc/restic/password init
```

---

## Tips

- Use `--tag` to label snapshots by environment (`prod`, `staging`) or purpose (`pre-deploy`).
- Always run `forget` with `--prune` to actually free disk space; without it, data is only unreferenced.
- Run `check` periodically (weekly is typical) to catch silent corruption early.
- Combine backup + forget in a single orchestration workflow: backup → forget → check.
- Use `--exclude-file /etc/restic/excludes.txt` for complex exclusion lists.

---

## Requirements

- `restic` installed on the agent host
- Repository must be initialised before first use
