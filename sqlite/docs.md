# SQLite Plugin

Manage SQLite databases on the agent host. Supports exporting SQL dumps, restoring from dumps, using the SQLite online backup API, running queries, vacuuming, and integrity checking.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Database File** | Absolute path to the SQLite `.db` file |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Extra Flags** | Additional `sqlite3` CLI flags |

---

## dump — Export the Database as a Compressed SQL File

Export the database as a compressed SQL text file using `.dump`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |
| **Dump File Path** | Yes | Output file path; supports `%Y-%m-%d` date placeholders |
| **Extra Flags** | No | Additional `sqlite3` flags |

### Example

```
Operation:        dump
Database File:    /var/lib/myapp/app.db
Dump File:        /backups/app_%Y-%m-%d.sql.gz
```

---

## backup — Create a Consistent Binary Backup

Create a consistent binary copy using the SQLite online backup API (`sqlite3 .backup`).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |
| **Dump File Path** | Yes | Output file path; supports `%Y-%m-%d` date placeholders |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        backup
Database File:    /var/lib/myapp/app.db
Dump File:        /backups/app_%Y-%m-%d.db
```

---

## restore — Recreate a Database from a Dump File

Restore a database from a dump file.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Target database file path (will be created) |
| **Restore File Path** | Yes | Path to the dump file (`.sql` or `.sql.gz`) |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        restore
Database File:    /var/lib/myapp/app-restored.db
Restore File:     /backups/app_2026-05-15.sql.gz
```

---

## query — Execute an Arbitrary SQL Statement

Execute an arbitrary SQL statement.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |
| **SQL Query** | Yes | The SQL statement to execute |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        query
Database File:    /var/lib/myapp/app.db
Query:            SELECT COUNT(*) FROM users WHERE active = 1;
```

---

## vacuum — Rebuild the Database and Reclaim Free Space

Run `VACUUM` to rebuild the database and reclaim free space.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        vacuum
Database File:    /var/lib/myapp/app.db
```

---

## integrity-check — Verify the Database

Run `PRAGMA integrity_check` to verify the database is not corrupt.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        integrity-check
Database File:    /var/lib/myapp/app.db
```

---

## tables — List All Tables

List all tables in the database.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database File** | Yes | Path to the SQLite `.db` file |

### Example

```
Operation:        tables
Database File:    /var/lib/myapp/app.db
```

---

## Dump File Date Placeholders

The **Dump File Path** field supports `date` strftime placeholders:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day of month |
| `%H%M%S` | Time |

Example: `/backups/app_%Y-%m-%d_%H%M%S.sql.gz`

---

## dump vs backup

| Method | Operation | Output | Description |
|--------|-----------|--------|-------------|
| SQL dump | `dump` | `.sql.gz` text | Portable SQL — can be restored on any SQLite version |
| Binary backup | `backup` | `.db` binary | Exact copy of the file using the hot-backup API — zero corruption risk even with active writes |

Use `backup` for automated daily snapshots (fastest, safest). Use `dump` when you need a human-readable or cross-platform export.

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
