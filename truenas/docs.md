# TrueNAS Plugin

Control a TrueNAS CORE or SCALE server remotely via the REST API v2.0. Create ZFS snapshots, trigger replication and cloud sync tasks, list datasets, and start pool scrubs — all without SSH access to the NAS.

Compatible with: **TrueNAS CORE 13+** and **TrueNAS SCALE 22+**

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **TrueNAS Host** | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Path to a file on the agent containing the TrueNAS API key |
| **Verify SSL** | Whether to verify SSL certificate (default: no) |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **API Timeout (seconds)** | Maximum wait time for an API response (default: 30) |

---

## snapshot — Create a ZFS Snapshot

Create a ZFS snapshot of a dataset.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Dataset** | Yes | ZFS dataset path, e.g. `tank/data` |
| **Snapshot Name** | No | Snapshot label; supports strftime placeholders (default: `auto-%Y-%m-%dT%H:%M:%S`) |
| **Recursive Snapshot** | No | Snapshot all child datasets too (default: no) |

### Example

```
Operation:            snapshot
TrueNAS Host:         192.168.1.10
API Key File:         /etc/truenas/api.key
Verify SSL:           no
Dataset:              tank/data
Snapshot Name:        auto-%Y-%m-%dT%H:%M:%S
Recursive Snapshot:   no
```

---

## delete-snapshot — Delete a Named Snapshot

Delete a named snapshot.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Dataset** | Yes | ZFS dataset path |
| **Snapshot Name** | Yes | Name of the snapshot to delete |

### Example

```
Operation:       delete-snapshot
TrueNAS Host:    192.168.1.10
API Key File:    /etc/truenas/api.key
Verify SSL:      no
Dataset:         tank/data
Snapshot Name:   auto-2026-04-01T02:00:00
```

---

## list-snapshots — List All Snapshots

List all snapshots, optionally filtered to a dataset.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Dataset** | No | Filter to a specific dataset (optional) |

### Example

```
Operation:     list-snapshots
TrueNAS Host:  192.168.1.10
API Key File:  /etc/truenas/api.key
Verify SSL:    no
Dataset:       tank/data
```

---

## replication-run — Trigger an Existing Replication Task

Trigger an existing replication task by name.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Task Name** | Yes | Name of the task as shown in the TrueNAS UI (case-insensitive) |

### Example

```
Operation:     replication-run
TrueNAS Host:  192.168.1.10
API Key File:  /etc/truenas/api.key
Verify SSL:    no
Task Name:     Daily Offsite Replication
```

---

## cloudsync-run — Trigger an Existing Cloud Sync Task

Trigger an existing cloud sync task by name.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Task Name** | Yes | Name of the task as shown in the TrueNAS UI (case-insensitive) |

### Example

```
Operation:     cloudsync-run
TrueNAS Host:  192.168.1.10
API Key File:  /etc/truenas/api.key
Verify SSL:    no
Task Name:     Backblaze B2 Daily Sync
```

---

## dataset-list — List Datasets with Space Usage

List datasets with used/available space.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Pool Name** | Yes | ZFS pool name |

### Example

```
Operation:     dataset-list
TrueNAS Host:  192.168.1.10
API Key File:  /etc/truenas/api.key
Verify SSL:    no
Pool Name:     tank
```

---

## scrub — Start a Pool Integrity Scrub

Start a pool integrity scrub.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **TrueNAS Host** | Yes | Hostname, IP address, or full URL of the TrueNAS server |
| **API Key File** | Yes | Path to a file containing the TrueNAS API key |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Pool Name** | Yes | ZFS pool name |

### Example

```
Operation:     scrub
TrueNAS Host:  192.168.1.10
API Key File:  /etc/truenas/api.key
Verify SSL:    no
Pool Name:     tank
```

---

## API Key Setup

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

## Snapshot Name Templates

The snapshot name field supports `date` strftime placeholders:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day (01–31) |
| `%H:%M:%S` | Time |

Example: `auto-%Y-%m-%dT%H:%M:%S` → `auto-2026-05-16T02:00:00`

---

## Tips

- Task names are case-insensitive but must match exactly what is shown in the TrueNAS UI
- Replication and cloud sync tasks must already exist in TrueNAS before you can trigger them
- Use `snapshot` before `replication-run` to ensure consistent point-in-time backups
- Scrubs are I/O intensive — schedule them during low-usage periods
- The API key is secure: stored in a file and never exposed in logs or process arguments

---

## Requirements

- TrueNAS CORE 13+ or TrueNAS SCALE 22+
- API access enabled on the TrueNAS server
- Valid API key with appropriate permissions
- Network connectivity from Orchelium agent to TrueNAS host

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
