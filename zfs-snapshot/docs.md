# ZFS Snapshot Plugin

Create, manage, and replicate ZFS snapshots directly on the agent host. Snapshots are instantaneous, space-efficient point-in-time copies of a ZFS dataset.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `snapshot` | Create a new snapshot of a dataset |
| `destroy` | Delete a snapshot |
| `list` | List all snapshots of a dataset |
| `send` | Stream a snapshot to a remote host or local file |
| `rollback` | Roll the dataset back to a snapshot |
| `clone` | Create a writeable clone of a snapshot as a new dataset |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Dataset** | Yes | All | ZFS dataset, e.g. `pool/data` or `tank/home` |
| **Snapshot Name** | snapshot, destroy, send, rollback, clone | Snapshot label. Supports `%Y-%m-%dT%H:%M:%S` strftime placeholders |
| **Recursive** | No | snapshot, destroy, list, send | Apply to all child datasets (`yes`/`no`) |
| **Incremental From** | No | send | Base snapshot for incremental stream |
| **Send Target** | send | Remote host (`user@host`) or local file path |
| **Remote Receive Dataset** | send (SSH) | Target dataset on the remote host |
| **Clone Target Dataset** | clone | New dataset name for the clone |
| **Extra Flags** | No | All | Any additional `zfs` flags |

---

## Usage Examples

### Take a snapshot

```
Operation:      snapshot
Dataset:        tank/home
Snapshot Name:  auto-%Y-%m-%dT%H:%M:%S
Recursive:      yes
```

### List snapshots

```
Operation:    list
Dataset:      tank/home
```

### Send full stream to remote host

```
Operation:           send
Dataset:             tank/data
Snapshot Name:       auto-2026-05-15T02:00:00
Send Target:         root@backup-server
Remote Dataset:      backup/data
```

### Incremental send

```
Operation:           send
Dataset:             tank/data
Snapshot Name:       auto-2026-05-15T02:00:00
Incremental From:    auto-2026-05-14T02:00:00
Send Target:         root@backup-server
Remote Dataset:      backup/data
```

### Send to a local file

```
Operation:       send
Dataset:         pool/vm-disks
Snapshot Name:   pre-upgrade
Send Target:     /mnt/external/vm-disks.zfs
```

### Rollback a dataset

```
Operation:       rollback
Dataset:         tank/db
Snapshot Name:   pre-upgrade
```

### Clone a snapshot

```
Operation:          clone
Dataset:            tank/home
Snapshot Name:      auto-2026-05-14T00:00:00
Clone Target:       tank/home-restore
```

### Destroy an old snapshot

```
Operation:       destroy
Dataset:         tank/home
Snapshot Name:   auto-2026-04-01T00:00:00
Recursive:       no
```

---

## Snapshot Name Templates

The snapshot name field supports `date` strftime placeholders so names are timestamped automatically:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day (01–31) |
| `%H:%M:%S` | Time |

Example: `auto-%Y-%m-%dT%H:%M:%S` → `auto-2026-05-15T02:00:00`

---

## Tips

- Snapshots are instant and consume no space initially — disk usage grows as the dataset changes.
- Use `rollback` carefully: by default, it requires all newer snapshots to be destroyed first. Pass `-r` in Extra Flags to destroy them automatically.
- For regular automated snapshots, use a `snapshot` → `destroy` (old ones) orchestration pattern.
- Incremental sends are much faster and produce smaller streams than full sends.
- The `clone` operation creates a fully independent, writeable dataset — ideal for testing restores.

---

## Requirements

- ZFS installed and pool(s) imported on the agent host
- Sufficient pool capacity for snapshot retention
