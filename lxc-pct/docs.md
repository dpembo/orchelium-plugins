# LXC Container (PCT) Plugin

Manage Proxmox LXC containers using the `pct` command-line tool. Supports container lifecycle management, command execution, snapshots, cloning, and listing.

---

## Common Parameters

Most operations require:

| Parameter | Description |
|-----------|-------------|
| **Container ID (CTID)** | Proxmox container ID, e.g. `101` |

---

## start — Start a Stopped Container

Start a stopped container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |

### Example

```
Operation:     start
Container ID:  101
```

---

## stop — Stop a Running Container

Stop a running container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |
| **Stop Timeout (seconds)** | No | Grace period before force-stop (default: 60s) |
| **Force Stop** | No | Force-stop even if container does not respond |

### Example

```
Operation:     stop
Container ID:  101
Stop Timeout:  30
Force Stop:    no
```

---

## restart — Restart a Container

Restart a container (stop + start).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |

### Example

```
Operation:        restart
Container ID:     101
```

---

## exec — Execute a Command Inside a Container

Run a command inside a running container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |
| **Exec Command** | Yes | Command to run inside the container |

### Example

```
Operation:       exec
Container ID:    205
Exec Command:    bash -c 'pg_dump mydb | gzip > /tmp/dump.sql.gz'
```

---

## status — Show Container Status

Show the current status of a container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |

### Example

```
Operation:     status
Container ID:  101
```

---

## snapshot — Take a Snapshot of a Container

Create a snapshot of a container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |
| **Snapshot Name** | Yes | Name for the snapshot |
| **Snapshot Description** | No | Optional text description |

### Example

```
Operation:       snapshot
Container ID:    101
Snapshot Name:   pre-update
Description:     Before package upgrade
```

---

## rollback — Roll Back to a Snapshot

Roll back a container to a named snapshot.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |
| **Snapshot Name** | Yes | Name of the snapshot to restore |

### Example

```
Operation:        rollback
Container ID:     101
Snapshot Name:    pre-update
```

---

## destroy-snapshot — Delete a Snapshot

Delete a named snapshot.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Proxmox container ID |
| **Snapshot Name** | Yes | Name of the snapshot to delete |

### Example

```
Operation:        destroy-snapshot
Container ID:     101
Snapshot Name:    pre-update
```

---

## clone — Clone a Container

Clone a container to a new CTID.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container ID (CTID)** | Yes | Source container ID |
| **Clone Target CTID** | Yes | New container ID for the clone |
| **Clone Hostname** | No | Hostname for the cloned container |
| **Full Clone** | No | `yes` = full independent copy; `no` = linked clone (default) |

### Example

```
Operation:           clone
Container ID:        101
Clone Target CTID:   201
Clone Hostname:      myapp-test
Full Clone:          yes
```

---

## list — List All Containers

List all containers on the node.

### Parameters

(No operation-specific parameters)

### Example

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
