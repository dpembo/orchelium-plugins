# Proxmox VM Backup Plugin

Wraps the `vzdump` utility to back up Proxmox VE virtual machines and LXC containers. Supports all three Proxmox backup modes and integrates with Proxmox storage targets or a custom dump directory.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **VM / CT ID** | Yes | — | One or more VM/container IDs separated by spaces, or `all` |
| **Backup Mode** | Yes | `snapshot` | How to freeze the guest during backup |
| **Compression** | No | `zstd` | Archive compression algorithm |
| **Proxmox Storage ID** | No | — | Proxmox storage target (e.g. `backups-nfs`). Takes precedence over Dump Directory |
| **Dump Directory** | No | — | Fallback filesystem path to write archives |
| **Prune / Retention Policy** | No | — | e.g. `keep-last=7` — removes older archives after backup |
| **Email Notification** | No | — | Send backup report to this address |
| **Backup Notes Template** | No | — | Template string added as notes to the backup |
| **Extra Flags** | No | — | Any additional `vzdump` flags |

---

## Backup Modes

| Mode | Description |
|------|-------------|
| `snapshot` | Uses QEMU/LXC snapshot mechanism — no downtime, requires hardware support |
| `suspend` | Suspends the guest briefly during backup — minimal downtime |
| `stop` | Stops the guest for a clean backup — maximum consistency, causes downtime |

---

## Compression Options

| Value | Description |
|-------|-------------|
| `zstd` | Fast compression with excellent ratios (recommended) |
| `gzip` | Compatible, widely supported, slower than zstd |
| `lzo` | Fast, lower compression ratio |
| `none` | No compression — fastest, largest files |

---

## Usage Examples

### Back up a single VM

```
VM / CT ID:     100
Backup Mode:    snapshot
Compression:    zstd
Storage ID:     local-bkp
```

### Back up multiple containers

```
VM / CT ID:     201 202 203
Backup Mode:    suspend
Compression:    zstd
Storage ID:     nfs-backup
Prune Policy:   keep-last=5
```

### Back up all VMs and CTs nightly

```
VM / CT ID:     all
Backup Mode:    snapshot
Compression:    zstd
Storage ID:     backups-nfs
Prune Policy:   keep-last=7
Email:          admin@example.com
```

### Write to a custom directory

```
VM / CT ID:     100
Backup Mode:    snapshot
Compression:    gzip
Dump Directory: /mnt/external/proxmox-dumps
Extra Flags:    --remove 0
```

---

## Notes Template Variables

The `--notes-template` option supports Proxmox variables:

| Variable | Description |
|----------|-------------|
| `{{guestname}}` | Name of the guest |
| `{{node}}` | Proxmox node name |
| `{{cluster}}` | Cluster name (if applicable) |

Example: `Orchelium backup — {{guestname}} on {{node}}`

---

## Tips

- `snapshot` mode is preferred for production VMs — it uses temporary QEMU snapshots to ensure consistency without stopping the guest.
- For LXC containers, `suspend` mode is typically more reliable than `snapshot` since container snapshotting requires a ZFS/BTRFS storage.
- Always specify either a **Storage ID** or a **Dump Directory** — omitting both will cause the backup to fail.
- Set `--remove 0` in Extra Flags to disable Proxmox's built-in rotation and manage retention yourself.

---

## Requirements

- Must run on a Proxmox VE host (or via SSH on a PVE node)
- `vzdump` must be available (it is included with Proxmox VE)
- Sufficient disk space in the target storage
