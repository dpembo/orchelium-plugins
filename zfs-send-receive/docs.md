# ZFS Send / Receive Plugin

Replicates a ZFS dataset to a remote host or local file using `zfs send | zfs receive`. Supports full and incremental streams, encrypted (raw) transfers, and resumable operations.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Source Dataset** | ZFS dataset to replicate, e.g. `tank/data` |
| **Source Snapshot** | Snapshot to send (use `latest` for most recent, or specify name) |
| **Target Type** | Destination: `ssh`, `local`, or `file` |

---

## send — Stream a Snapshot to Remote or Local Target

Stream a snapshot to a remote host, local dataset, or file for backup or replication.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Source Dataset** | Yes | ZFS dataset to replicate, e.g. `tank/data` |
| **Source Snapshot** | Yes | Snapshot to send; use `latest` for most recent |
| **Target Type** | Yes | Destination: `ssh`, `local`, or `file` |
| **Incremental From** | No | Base snapshot for incremental stream (enables delta sync) |
| **Recursive (-R)** | No | Include all child datasets in the stream (default: no) |
| **Raw / Encrypted (-w)** | No | Send the raw encrypted stream (preserves on-disk encryption) |
| **Resume Interrupted Transfer** | No | Use `zfs send -t` to resume a partial transfer (default: no) |

### Parameters for SSH Target

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Target Host** | Yes | Remote host, e.g. `user@backup-host` or `user@192.168.1.10` |
| **Target Dataset** | Yes | Destination dataset on the target |
| **SSH Key** | No | Path to a private key for SSH authentication |
| **SSH Port** | No | Custom SSH port (default: 22) |

### Parameters for Local Target

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Target Dataset** | Yes | Destination dataset on the local host |

### Parameters for File Target

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Target File** | Yes | Local file path for the stream, e.g. `/mnt/external/data.zfs` |

### Example: Full SSH Replication

```
Operation:              send
Source Dataset:         tank/data
Source Snapshot:        latest
Target Type:            ssh
Target Host:            root@backup-server
Target Dataset:         backup/data
Incremental From:       (leave empty for full replication)
Recursive:              no
Raw / Encrypted:        no
Resume Transfer:        no
```

### Example: Incremental SSH Replication

```
Operation:              send
Source Dataset:         tank/data
Source Snapshot:        auto-2026-05-15T02:00:00
Target Type:            ssh
Target Host:            root@backup-server
Target Dataset:         backup/data
Incremental From:       auto-2026-05-14T02:00:00
Recursive:              no
Raw / Encrypted:        no
Resume Transfer:        no
```

### Example: Recursive Replication with Custom SSH Key

```
Operation:              send
Source Dataset:         tank/vms
Source Snapshot:        latest
Target Type:            ssh
Target Host:            backupuser@192.168.1.50
Target Dataset:         replication/vms
SSH Key:                /root/.ssh/id_ed25519
SSH Port:               2222
Incremental From:       (empty for full)
Recursive:              yes
Raw / Encrypted:        no
Resume Transfer:        no
```

### Example: Export to File for Offline Backup

```
Operation:              send
Source Dataset:         pool/db
Source Snapshot:        pre-migration
Target Type:            file
Target File:            /mnt/external/db-pre-migration.zfs
Incremental From:       (empty for full)
Recursive:              no
Raw / Encrypted:        no
Resume Transfer:        no
```

### Example: Local Dataset Replication

```
Operation:              send
Source Dataset:         tank/data
Source Snapshot:        latest
Target Type:            local
Target Dataset:         tank/data-replica
Incremental From:       (empty for full)
Recursive:              no
Raw / Encrypted:        no
Resume Transfer:        no
```

### Example: Encrypted (Raw) Replication

```
Operation:              send
Source Dataset:         tank/encrypted-data
Source Snapshot:        latest
Target Type:            ssh
Target Host:            root@backup-server
Target Dataset:         backup/encrypted-data
Raw / Encrypted:        yes
Incremental From:       (empty for full)
Recursive:              no
Resume Transfer:        no
```

---

## Target Types

| Type | Description | Use Case |
|------|-------------|----------|
| `ssh` | Stream over SSH to a remote dataset | Remote backup host, offsite replication |
| `local` | Pipe directly to `zfs receive` on the local host | Local pool replication, test restores |
| `file` | Write the stream to a `.zfs` file for offline transport | Archival, offline backup, portable media |

---

## Incremental Replication

Incremental sends transfer only the changes between two snapshots, resulting in smaller streams and faster transfers.

| Aspect | Full Send | Incremental Send |
|--------|-----------|------------------|
| **Speed** | Slower (entire dataset) | Much faster (delta only) |
| **Data Transfer** | Largest | Smallest |
| **Target Requirement** | Fresh dataset | Pre-existing target with base snapshot |
| **Prerequisites** | None | Base snapshot must exist on target |

**Workflow:**
1. First time: Full replication (`Incremental From: empty`)
2. Subsequently: Set `Incremental From` to the last snapshot sent

---

## Resumable Transfers

For large streams interrupted by network issues, set **Resume Interrupted Transfer** to `yes`. The plugin will use `zfs send -t $(zfs get receive_resume_token ...)` on the next run.

**Prerequisites:**
- The target must support receive resumption (`zpool` feature `extensible_dataset` enabled)
- The partial receive token is stored on the target dataset

---

## Snapshot Name Placeholders

Snapshots can use `date` strftime placeholders for automatic timestamping:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day (01–31) |
| `%H:%M:%S` | Time |
| `latest` | Most recent snapshot (special) |

Example: `auto-%Y-%m-%dT%H:%M:%S` → `auto-2026-05-15T02:00:00`

---

## Encrypted (Raw) Transfers

Using **Raw / Encrypted: yes** sends the raw encrypted stream:
- Preserves on-disk encryption keys
- Bypass running kernel's encryption
- Key is never exposed on the receiving host
- Useful for replicating encrypted datasets to hosts without the encryption key

---

## Restoring from File

To restore from a file stream (outside Orchelium):

```bash
# On the target host
zfs receive tank/db-restore < /mnt/external/db-pre-migration.zfs
```

Or to restore incrementally:

```bash
zfs receive -F tank/db-restore < /mnt/external/db-incremental.zfs
```

---

## Tips

- Use `latest` as the source snapshot to always send the most recent snapshot without knowing its name
- Combine with the **ZFS Snapshot** plugin earlier in the orchestration to snapshot → replicate in sequence
- Add `-o readonly=on` to Receive Flags when the target is a replica that should not be modified directly
- Encrypted streams (`Raw: yes`) bypass the running kernel's encryption — the key is never exposed on the receiving host
- For first-time full replication of large datasets, run the initial send manually outside of Orchelium to avoid orchestration timeouts, then use incremental sends in the workflow
- Monitor SSH connections: large streams may timeout if SSH idle timeout is too low

---

## Requirements

- ZFS installed on both source (agent) and target hosts
- SSH access with appropriate permissions for remote targets
- Both source snapshot and (for incremental) incremental-from snapshot must exist
- Target dataset must exist for local/SSH targets (or set `zfs receive -F` flag)
