# ZFS Send / Receive Plugin

Replicates a ZFS dataset to a remote host or local file using `zfs send | zfs receive`. Supports full and incremental streams, encrypted (raw) transfers, and resumable operations.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Source Dataset** | Yes | — | ZFS dataset to replicate, e.g. `tank/data` |
| **Source Snapshot** | Yes | `latest` | Snapshot to send. Use `latest` to auto-select the most recent snapshot |
| **Incremental From** | No | — | Base snapshot for an incremental stream |
| **Recursive (-R)** | No | `no` | Include all child datasets in the stream |
| **Target Type** | Yes | `ssh` | Destination: `ssh`, `local`, or `file` |
| **Target Host** | ssh | — | Remote host, e.g. `user@backup-host` or `user@192.168.1.10` |
| **Target Dataset** | ssh, local | — | Destination dataset on the target |
| **Target File** | file | — | Local file path for the stream, e.g. `/mnt/external/data.zfs` |
| **SSH Key** | No | — | Path to a private key for SSH authentication |
| **SSH Port** | No | `22` | Custom SSH port |
| **Raw / Encrypted (-w)** | No | `no` | Send the raw encrypted stream (preserves on-disk encryption) |
| **Resume Interrupted Transfer** | No | `no` | Use `-s` / `zfs send -t` to resume a partial transfer |
| **Receive Flags** | No | — | Additional `zfs receive` flags, e.g. `-u -o mountpoint=none` |
| **Extra Send Flags** | No | — | Additional `zfs send` flags, e.g. `-v -c` |

---

## Target Types

| Type | Description |
|------|-------------|
| `ssh` | Stream over SSH to a remote dataset |
| `local` | Pipe directly to `zfs receive` on the same host |
| `file` | Write the stream to a `.zfs` file for offline transport |

---

## Usage Examples

### Full replication to a remote host

```
Source Dataset:    tank/data
Source Snapshot:   latest
Target Type:       ssh
Target Host:       root@backup-server
Target Dataset:    backup/data
```

### Incremental replication

```
Source Dataset:       tank/data
Source Snapshot:      auto-2026-05-15T02:00:00
Incremental From:     auto-2026-05-14T02:00:00
Target Type:          ssh
Target Host:          root@backup-server
Target Dataset:       backup/data
```

### Recursive replication with custom SSH key

```
Source Dataset:    tank/vms
Source Snapshot:   latest
Recursive:         yes
Target Type:       ssh
Target Host:       backupuser@192.168.1.50
Target Dataset:    replication/vms
SSH Key:           /root/.ssh/id_ed25519
SSH Port:          2222
```

### Export to a file for offline backup

```
Source Dataset:    pool/db
Source Snapshot:   pre-migration
Target Type:       file
Target File:       /mnt/external/db-pre-migration.zfs
```

### Receive the file back later

Run on the target host (outside Orchelium):

```bash
zfs receive tank/db-restore < /mnt/external/db-pre-migration.zfs
```

### Encrypted (raw) replication

```
Source Dataset:    tank/encrypted-data
Source Snapshot:   latest
Target Type:       ssh
Target Host:       root@backup-server
Target Dataset:    backup/encrypted-data
Raw:               yes
```

---

## Resumable Transfers

For large streams interrupted by network issues, set **Resume Interrupted Transfer** to `yes`. The plugin will use `zfs send -t $(zfs get receive_resume_token ...)` on the next run.

**Prerequisites:**
- The target must support receive resumption (`zpool` feature `extensible_dataset` enabled)
- The partial receive token is stored on the target dataset

---

## Tips

- Use `latest` as the source snapshot to always send the most recent snapshot without knowing its name.
- Combine with the **ZFS Snapshot** plugin earlier in the orchestration to snapshot → replicate in sequence.
- Add `-o readonly=on` to Receive Flags when the target is a replica that should not be modified directly.
- Encrypted streams (`-w`) bypass the running kernel's encryption — the key is never exposed on the receiving host.
- For first-time full replication of large datasets, run the initial send manually to avoid orchestration timeouts, then use incremental sends in the workflow.

---

## Requirements

- ZFS installed on both source (agent) and target hosts
- SSH access with appropriate permissions for remote targets
- Both source snapshot and (for incremental) incremental-from snapshot must exist
