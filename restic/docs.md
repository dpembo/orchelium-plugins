# Restic Backup Plugin

Restic is a modern, fast, secure backup program that supports deduplication and encryption. It can store backups in local directories, SFTP servers, S3, Backblaze B2, and many other backends.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `backup` | Create a new snapshot of the specified paths |
| `forget` | Apply a retention policy and remove old snapshots |
| `check` | Verify the repository integrity |
| `snapshots` | List all snapshots in the repository |
| `restore` | Restore a snapshot to a target directory |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Repository** | Yes | All | Repository URL: local path, `sftp:user@host:/path`, `s3:s3.amazonaws.com/bucket`, etc. |
| **Password File** | Yes | All | Path to a file containing the repository password |
| **Paths to Back Up** | backup | Space-separated list of paths to include in the snapshot |
| **Tags** | No | backup, forget | Space-separated tags for the snapshot |
| **Exclude Patterns** | No | backup | Space-separated glob patterns to exclude |
| **Forget / Retention Policy** | forget | Flags like `--keep-daily 7 --keep-weekly 4 --keep-monthly 12` |
| **Snapshot ID** | restore | The snapshot ID to restore (default: `latest`) |
| **Restore Target** | restore | Directory to restore files into |
| **Extra Flags** | No | All | Any additional restic flags |

---

## Usage Examples

### Back up home directory and web root

```
Operation:        backup
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
Paths:            /home/dave /var/www
Tags:             daily web
Exclude:          *.log .cache
```

### Back up to S3

```
Operation:        backup
Repository:       s3:s3.amazonaws.com/my-backup-bucket
Password File:    /etc/restic/s3-password
Paths:            /var/lib/postgresql
Extra Flags:      --verbose
```

> **Note:** For S3, you must also set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`
> as environment variables on the agent host (e.g. in `/etc/environment` or `.profile`).

### Apply retention policy

```
Operation:           forget
Repository:          /mnt/backup/restic-repo
Password File:       /etc/restic/password
Forget Policy:       --keep-daily 7 --keep-weekly 4 --keep-monthly 12 --prune
Tags:                daily
```

### Restore latest snapshot

```
Operation:           restore
Repository:          /mnt/backup/restic-repo
Password File:       /etc/restic/password
Snapshot ID:         latest
Restore Target:      /tmp/restore
```

### List all snapshots

```
Operation:        snapshots
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
```

### Verify repository

```
Operation:        check
Repository:       /mnt/backup/restic-repo
Password File:    /etc/restic/password
Extra Flags:      --read-data-subset=10%
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
