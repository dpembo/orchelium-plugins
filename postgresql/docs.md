# PostgreSQL Plugin

Run backups, restores, queries, and database management tasks against a PostgreSQL server. Authentication is handled securely via a `.pgpass` file.

---

## Common Parameters

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Host** | PostgreSQL server hostname or IP (default: `localhost`) |
| **Port** | PostgreSQL server port (default: `5432`) |
| **Username** | PostgreSQL username (default: `postgres`) |
| **Password File (.pgpass)** | Path to a `.pgpass` file for authentication |

### .pgpass File Format

The `.pgpass` file avoids passwords on the command line. Each line follows:

```
hostname:port:database:username:password
```

Example:

```
localhost:5432:*:backupuser:s3cr3t
```

```bash
chmod 600 /root/.pgpass
```

---

## dump — Export a Single Database

Export a single database using `pg_dump`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Database name to dump |
| **Dump File Path** | Yes | Destination file; supports `%Y-%m-%d` date placeholders |
| **Dump Format** | No | `custom`, `plain`, `directory`, `tar` (default: `custom`) |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |
| **Extra Flags** | No | Additional `pg_dump` flags |

### Example

```
Operation:       dump
Database:        myapp
Dump File:       /backups/myapp_%Y-%m-%d.dump
Dump Format:     custom
Extra Flags:     --no-owner --no-acl
```

---

## dump-all — Export All Databases

Export all databases with roles and tablespaces using `pg_dumpall`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Dump File Path** | Yes | Destination file; supports `%Y-%m-%d` date placeholders |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:       dump-all
Dump File:       /backups/all-databases_%Y-%m-%d.sql.gz
```

---

## restore — Restore a Database from a Dump File

Restore a database from a dump file using `pg_restore` or `psql`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Target database name |
| **Restore File Path** | Yes | Path to the dump file |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |
| **Extra Flags** | No | Additional `pg_restore`/`psql` flags |

### Example

```
Operation:        restore
Database:         myapp
Restore File:     /backups/myapp_2026-05-15.dump
Extra Flags:      --no-owner --clean
```

The plugin auto-detects `.sql` files and uses `psql` instead of `pg_restore`.

---

## query — Run an Arbitrary SQL Statement

Execute an arbitrary SQL statement using `psql`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Target database |
| **SQL Query** | Yes | SQL statement to execute |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |

### Example

```
Operation:        query
Database:         myapp
Query:            SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;
```

---

## list-databases — List All Databases

List all databases on the server.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |

### Example

```
Operation:        list-databases
```

---

## create-database — Create a New Database

Create a new database.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Name of the new database |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |

### Example

```
Operation:        create-database
Database:         myapp_staging
```

---

## drop-database — Drop (Delete) a Database

Drop (delete) an existing database. **Warning: This is irreversible!**

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Name of the database to drop |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |

### Example

```
Operation:        drop-database
Database:         old_staging
```

---

## vacuum — Run VACUUM ANALYZE

Run `VACUUM ANALYZE` on a database to reclaim space and update statistics.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Database** | Yes | Target database |
| **Host** | No | PostgreSQL server hostname |
| **Port** | No | PostgreSQL server port |
| **Username** | No | PostgreSQL username |
| **Password File (.pgpass)** | No | Path to `.pgpass` file |

### Example

```
Operation:        vacuum
Database:         myapp
```

---

## Dump Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| `custom` | `.dump` | Default compressed format — best for `pg_restore` (recommended) |
| `plain` | `.sql` | Plain SQL text — compatible with `psql` |
| `directory` | directory | Parallel dump; target must be a directory path |
| `tar` | `.tar` | TAR archive |

---

## Dump File Date Placeholders

The **Dump File Path** field supports `date` strftime placeholders:

| Placeholder | Output |
|-------------|--------|
| `%Y` | 4-digit year |
| `%m` | Month (01–12) |
| `%d` | Day of month |
| `%H%M%S` | Time |

Example: `/backups/myapp_%Y-%m-%d_%H%M%S.dump`

---

## Tips

- Custom format (`-Fc`) produces the most flexible dumps — you can restore individual tables with `pg_restore -t tablename`.
- Use `--no-owner --no-acl` when restoring to a different user or environment.
- Add `--schema=public` to Extra Flags to limit the dump to a single schema.
- Run `vacuum` after bulk deletes or inserts to reclaim space and help the query planner.
- `dump-all` includes roles and tablespace definitions — useful for full server migrations.
- For large databases, use `directory` format with `--jobs=4` to parallelise the dump.

---

## Requirements

- `pg_dump`, `pg_dumpall`, `pg_restore`, and `psql` installed on the agent host
- PostgreSQL server accessible from the agent
