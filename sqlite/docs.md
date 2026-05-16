# SQLite Plugin

Manage SQLite databases on the agent host. Supports exporting SQL dumps, restoring from dumps, using the SQLite online backup API, running queries, vacuuming, and integrity checking.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `dump` | Export the database as a compressed SQL text file using `.dump` |
| `restore` | Recreate a database from a dump file |
| `backup` | Create a consistent binary copy using the SQLite online backup API (`sqlite3 .backup`) |
| `query` | Execute an arbitrary SQL statement |
| `vacuum` | Run `VACUUM` to rebuild the database and reclaim free space |
| `integrity-check` | Run `PRAGMA integrity_check` to verify the database |
| `tables` | List all tables in the database |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Operation** | Yes | — | Operation to perform |
| **Database File** | Yes | All | Absolute path to the SQLite `.db` file |
| **Dump / Backup File Path** | dump, backup | Output file path; supports `%Y-%m-%d` date placeholders |
| **Restore File Path** | restore | Path to the dump file to restore (`.sql` or `.sql.gz`) |
| **SQL Query** | query | The SQL statement to execute |
| **Extra Flags** | No | All | Additional `sqlite3` CLI flags |

---

## Dump vs Backup

| Method | Operation | Output | Description |
|--------|-----------|--------|-------------|
| SQL dump | `dump` | `.sql.gz` text | Portable SQL — can be restored on any SQLite version |
| Binary backup | `backup` | `.db` binary | Exact copy of the file using the hot-backup API — zero corruption risk even with active writes |

Use `backup` for automated daily snapshots (fastest, safest). Use `dump` when you need a human-readable or cross-platform export.

---

## Usage Examples

### Daily compressed SQL dump

```
Operation:        dump
Database File:    /var/lib/myapp/app.db
Dump File:        /backups/app_%Y-%m-%d.sql.gz
```

### Binary backup (recommended for live databases)

```
Operation:        backup
Database File:    /var/lib/myapp/app.db
Dump File:        /backups/app_%Y-%m-%d.db
```

### Restore from a dump

```
Operation:        restore
Database File:    /var/lib/myapp/app-restored.db
Restore File:     /backups/app_2026-05-15.sql.gz
```

### Run a query

```
Operation:        query
Database File:    /var/lib/myapp/app.db
Query:            SELECT COUNT(*) FROM users WHERE active = 1;
```

### Vacuum to reclaim space

```
Operation:        vacuum
Database File:    /var/lib/myapp/app.db
```

### Check database integrity

```
Operation:        integrity-check
Database File:    /var/lib/myapp/app.db
```

### List tables

```
Operation:        tables
Database File:    /var/lib/myapp/app.db
```

---

## Dump File Date Placeholders

The **Dump / Backup File Path** field supports `date` strftime placeholders:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day of month |
| `%H%M%S` | Time |

Example: `/backups/app_%Y-%m-%d_%H%M%S.sql.gz`

---

## Tips

- SQLite does not require a server process — the database file is accessed directly by the agent.
- The `backup` operation uses the SQLite online backup API, which works safely even while the database is open and being written to.
- For production databases, prefer `backup` over `dump` to avoid a momentary read lock during the dump.
- Run `integrity-check` after any restore to verify the file is valid before bringing the application back online.
- `VACUUM` rewrites the entire database — run it after bulk deletes or schema changes to recover file space.
- SQLite has no separate users or authentication; protect the `.db` file with filesystem permissions (`chmod 600`).

---

## Requirements

- `sqlite3` CLI installed on the agent host
- Read/write access to the database file
