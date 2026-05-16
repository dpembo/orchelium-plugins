# TrueNAS Plugin

Control a TrueNAS CORE or SCALE server remotely via the REST API v2.0. Create ZFS snapshots, trigger replication and cloud sync tasks, list datasets, and start pool scrubs — all without SSH access to the NAS.

Compatible with: **TrueNAS CORE 13+** and **TrueNAS SCALE 22+**

---

## Operations

| Operation | Description |
|-----------|-------------|
| `snapshot` | Create a ZFS snapshot of a dataset |
| `delete-snapshot` | Delete a named snapshot |
| `list-snapshots` | List all snapshots, optionally filtered to a dataset |
| `replication-run` | Trigger an existing replication task by name |
| `cloudsync-run` | Trigger an existing cloud sync task by name |
| `dataset-list` | List datasets with used/available space |
| `scrub` | Start a pool integrity scrub |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `snapshot` | Operation to perform |
| **TrueNAS Host** | Yes | — | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | — | Path to a file on the agent containing the TrueNAS API key |
| **Verify SSL** | No | `yes` | Set to `no` to skip certificate verification (self-signed certs) |
| **Dataset** | snapshot, delete-snapshot, list-snapshots | — | ZFS dataset path, e.g. `tank/data` |
| **Snapshot Name** | snapshot, delete-snapshot | `auto-%Y-%m-%dT%H:%M:%S` | Snapshot label; supports strftime date placeholders |
| **Recursive Snapshot** | No | `no` | Snapshot all child datasets too |
| **Task Name** | replication-run, cloudsync-run | — | Name of the task as shown in the TrueNAS UI (case-insensitive) |
| **Pool Name** | scrub, dataset-list | — | ZFS pool name |
| **API Timeout (seconds)** | No | `30` | Maximum wait time for an API response |

---

## Authentication — API Key Setup

1. In the TrueNAS UI, go to **Top Menu → API Keys → Add**
2. Give the key a name (e.g. `orchelium-agent`) and copy the generated key
3. Save it to a file on the agent host:

```bash
echo 'your-api-key-here' > /etc/truenas/api.key
chmod 600 /etc/truenas/api.key
```

4. Set **API Key File** to `/etc/truenas/api.key`

The key is read at runtime and passed in an HTTP `Authorization: Bearer` header — it never appears in process arguments or logs.

---

## Usage Examples

### Create a daily snapshot

```
Operation:       snapshot
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Dataset:         tank/data
Snapshot Name:   auto-%Y-%m-%dT%H:%M:%S
Recursive:       no
```

Produces a snapshot named e.g. `tank/data@auto-2026-05-16T02:00:00`.

### Recursive snapshot of an entire pool

```
Operation:       snapshot
Host:            truenas.local
API Key File:    /etc/truenas/api.key
Dataset:         tank
Snapshot Name:   nightly-%Y-%m-%d
Recursive:       yes
```

### Delete a snapshot

```
Operation:        delete-snapshot
Host:             192.168.1.10
API Key File:     /etc/truenas/api.key
Verify SSL:       no
Dataset:          tank/data
Snapshot Name:    auto-2026-04-01T02:00:00
```

### List snapshots for a dataset

```
Operation:       list-snapshots
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Dataset:         tank/data
```

### Trigger a replication task

```
Operation:       replication-run
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Task Name:       Daily Offsite Replication
```

The task name must match exactly (case-insensitive) what is shown in **Tasks → Replication Tasks** in the TrueNAS UI. The plugin looks up the task by name and submits it — you do not need to know the numeric task ID.

### Trigger a cloud sync task

```
Operation:       cloudsync-run
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Task Name:       Backblaze B2 Daily Sync
```

The task name corresponds to the **Description** field of the cloud sync task in the TrueNAS UI.

### List datasets

```
Operation:       dataset-list
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Pool:            tank
```

### Start a pool scrub

```
Operation:       scrub
Host:            192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Pool:            tank
```

---

## Snapshot Name Templates

The **Snapshot Name** field is passed through `date` strftime formatting at runtime:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day (01–31) |
| `%H` | Hour (00–23) |
| `%M` | Minute (00–59) |
| `%S` | Second (00–59) |

Example: `nightly-%Y-%m-%d` → `nightly-2026-05-16`

---

## Snapshot → Replicate workflow

A common pattern is to snapshot first, then immediately trigger replication:

```
[Start]
   ↓
[TrueNAS — snapshot]
   Dataset: tank/vms
   Snapshot Name: auto-%Y-%m-%dT%H:%M:%S
   Recursive: yes
   ↓
[TrueNAS — replication-run]
   Task Name: Daily Offsite Replication
   ↓
[End — Success]
```

---

## Self-Signed Certificates

Most home/lab TrueNAS installations use a self-signed certificate. Set **Verify SSL** to `no` to skip certificate verification:

```
Verify SSL: no
```

For production environments, either install a valid certificate (e.g. via Let's Encrypt in the TrueNAS UI) or import your internal CA into the agent's trust store and leave **Verify SSL** set to `yes`.

---

## Tips

- Replication and cloud sync tasks are defined once in the TrueNAS UI; this plugin simply triggers them. All scheduling, retention, and destination configuration stays in TrueNAS.
- For `recursive: yes` snapshots, TrueNAS creates a snapshot with the same name across all child datasets simultaneously.
- `dataset-list` shows used and available space — useful as a pre-flight check before a large backup.
- Pool scrubs are non-destructive reads that verify data integrity; they run in the background and do not block other operations.
- The plugin does not wait for replication/cloud sync jobs to complete — it submits the job and returns the job ID. TrueNAS runs the task asynchronously.

---

## Requirements

- TrueNAS CORE 13+ or TrueNAS SCALE 22+ with the REST API enabled (enabled by default)
- `curl` and `python3` installed on the agent host
- A TrueNAS API key with sufficient privileges (administrator or a role with dataset/snapshot/task access)
- Network access from the agent to the TrueNAS host on port 443 (or 80 for `http://` hosts)
