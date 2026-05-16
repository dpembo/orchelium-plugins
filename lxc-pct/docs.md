# LXC Container (PCT) Plugin

Manage Proxmox LXC containers using the `pct` command-line tool. Supports container lifecycle management, command execution, snapshots, cloning, and listing.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `start` | Start a stopped container |
| `stop` | Stop a running container |
| `restart` | Restart a container |
| `exec` | Execute a command inside a running container |
| `status` | Show the current status of a container |
| `snapshot` | Take a snapshot of a container |
| `rollback` | Roll back a container to a snapshot |
| `destroy-snapshot` | Delete a named snapshot |
| `clone` | Clone a container to a new CTID |
| `list` | List all containers on the node |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Operation** | Yes | — | Operation to perform |
| **Container ID (CTID)** | Yes (most) | All except list | Proxmox container ID, e.g. `101` |
| **Exec Command** | exec | Command to run inside the container |
| **Snapshot Name** | snapshot, rollback, destroy-snapshot | Name for the snapshot |
| **Snapshot Description** | No | snapshot | Optional text description |
| **Clone Target CTID** | clone | New container ID for the clone |
| **Clone Hostname** | No | clone | Hostname for the cloned container |
| **Full Clone** | No | clone | `yes` = full independent copy; `no` = linked clone (default) |
| **Stop Timeout (seconds)** | No | stop | Grace period before force-stop (default: 60s) |
| **Force Stop** | No | stop | Force-stop even if container does not respond (`yes`/`no`) |

---

## Usage Examples

### Stop → snapshot → start workflow

Chain three nodes to snapshot a running container safely:

```
Node 1: stop
  Container ID: 101
  Stop Timeout: 30

Node 2: snapshot
  Container ID: 101
  Snapshot Name: pre-update
  Description:   Before package upgrade

Node 3: start
  Container ID: 101
```

### Execute a backup command inside a container

```
Operation:       exec
Container ID:    205
Exec Command:    bash -c 'pg_dump mydb | gzip > /tmp/dump.sql.gz'
```

### Clone a container for testing

```
Operation:           clone
Container ID:        101
Clone Target CTID:   201
Clone Hostname:      myapp-test
Full Clone:          yes
```

### Roll back to a snapshot

```
Operation:        rollback
Container ID:     101
Snapshot Name:    pre-update
```

### Delete an old snapshot

```
Operation:        destroy-snapshot
Container ID:     101
Snapshot Name:    pre-update
```

### List all containers

```
Operation:    list
```

---

## Tips

- Snapshots require the container's storage to support them (ZFS, BTRFS, or LVM-thin). Standard directory storage does not support snapshots.
- Linked clones (`Full Clone: no`) share the base storage with the original and are faster to create but depend on it remaining intact.
- Full clones are independent — ideal for spinning up isolated test environments.
- Use `exec` to run database dumps or pre-backup scripts inside the container before copying data out.
- The `stop` → `snapshot` → `start` pattern gives you a consistent point-in-time snapshot with minimal downtime.

---

## Requirements

- Must run on a Proxmox VE host or via SSH on a PVE node
- `pct` must be available (included with Proxmox VE)
- Storage backend must support snapshots for snapshot/rollback/clone operations
