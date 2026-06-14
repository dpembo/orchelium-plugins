# ZFS Snapshot Plugin

Create, manage, and replicate ZFS snapshots directly on the agent host. Snapshots are instantaneous, space-efficient point-in-time copies of a ZFS dataset.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Dataset** | ZFS dataset, e.g. `pool/data` or `tank/home` |

---

## snapshot — Create a New Snapshot

Create a new snapshot of a dataset.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | ZFS dataset |
| **Snapshot Name** | No | Snapshot label; supports strftime placeholders (default: `auto-%Y-%m-%dT%H:%M:%S`) |
| **Recursive** | No | Apply to all child datasets (`yes`/`no`) |
| **Extra Flags** | No | Any additional `zfs` flags |

### Example

```
Operation:      snapshot
Dataset:        tank/home
Snapshot Name:  auto-%Y-%m-%dT%H:%M:%S
Recursive:      yes
```

---

## destroy — Delete a Snapshot

Delete a snapshot or range of snapshots.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | ZFS dataset |
| **Snapshot Name** | Yes | Snapshot label or pattern |
| **Recursive** | No | Apply to all child datasets |
| **Extra Flags** | No | Any additional `zfs` flags |

### Example

```
Operation:       destroy
Dataset:         tank/home
Snapshot Name:   auto-2026-04-01T00:00:00
Recursive:       no
```

---

## list — List All Snapshots

List all snapshots of a dataset.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | ZFS dataset |
| **Recursive** | No | Include child datasets |
| **Extra Flags** | No | Any additional `zfs` flags |

### Example

```
Operation:    list
Dataset:      tank/home
Recursive:    yes
```

---

## send — Stream a Snapshot

Stream a snapshot to a remote host or local file.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | ZFS dataset |
| **Snapshot Name** | Yes | Snapshot label |
| **Incremental From** | No | Base snapshot for incremental stream |
| **Send Target** | Yes | Remote host (`user@host`) or local file path |
| **Remote Receive Dataset** | No | Target dataset on the remote host (for SSH targets) |
| **Recursive** | No | Apply to all child datasets |
| **Extra Flags** | No | Any additional `zfs` flags |

### Example

```
Operation:           send
Dataset:             tank/data
Snapshot Name:       auto-2026-05-15T02:00:00
Send Target:         root@backup-server
Remote Dataset:      backup/data
Recursive:           no
```

---

## rollback — Roll Back to a Snapshot

Roll the dataset back to a snapshot.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | ZFS dataset |
| **Snapshot Name** | Yes | Snapshot label to restore |
| **Extra Flags** | No | Any additional `zfs` flags (e.g. `-r` to rollback child datasets) |

### Example

```
Operation:       rollback
Dataset:         tank/db
Snapshot Name:   pre-upgrade
Extra Flags:     -r
```

---

## clone — Create a Writeable Clone

Create a writeable clone of a snapshot as a new dataset.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dataset** | Yes | Source ZFS dataset |
| **Snapshot Name** | Yes | Snapshot label to clone |
| **Clone Target Dataset** | Yes | New dataset name for the clone |
| **Extra Flags** | No | Any additional `zfs` flags |

### Example

```
Operation:          clone
Dataset:            tank/home
Snapshot Name:      auto-2026-05-14T00:00:00
Clone Target:       tank/home-restore
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
