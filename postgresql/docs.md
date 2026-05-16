# PostgreSQL Plugin

Run backups, restores, queries, and database management tasks against a PostgreSQL server. Authentication is handled securely via a `.pgpass` file.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `dump` | Export a single database using `pg_dump` |
| `dump-all` | Export all databases using `pg_dumpall` |
| `restore` | Restore a database from a dump file using `pg_restore` or `psql` |
| `query` | Run an arbitrary SQL statement using `psql` |
| `list-databases` | List all databases on the server |
| `create-database` | Create a new database |
| `drop-database` | Drop (delete) a database |
| `vacuum` | Run `VACUUM ANALYZE` on a database to reclaim space and update statistics |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `dump` | Operation to perform |
| **Host** | No | `localhost` | PostgreSQL server hostname or IP |
| **Port** | No | `5432` | PostgreSQL server port |
| **Username** | No | `postgres` | PostgreSQL username |
| **Password File (.pgpass)** | No | — | Path to a `.pgpass` file for authentication |
| **Database** | Most operations | — | Target database name |
| **Dump File Path** | dump, dump-all | Destination file; supports `%Y-%m-%d` date placeholders |
| **Restore File Path** | restore | Path to the dump file to restore |
| **Dump Format** | No | `custom` | `custom`, `plain`, `directory`, `tar` |
| **SQL Query** | query | SQL statement to execute |
| **Extra Flags** | No | — | Any additional flags |

---

## .pgpass File Format

The `.pgpass` file avoids passwords on the command line. Each line follows the format:

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

Then set **Password File (.pgpass)** to `/root/.pgpass`.

---

## Dump Formats

| Format | Extension | Description |
|--------|-----------|-------------|
| `custom` | `.dump` | Default compressed format — best for `pg_restore` (recommended) |
| `plain` | `.sql` | Plain SQL text — compatible with `psql` |
| `directory` | directory | Parallel dump; target must be a directory path |
| `tar` | `.tar` | TAR archive |

---

## Usage Examples

### Dump a database (custom format)

```
Operation:       dump
Host:            localhost
Username:        postgres
Password File:   /root/.pgpass
Database:        myapp
Dump File:       /backups/myapp_%Y-%m-%d.dump
Extra Flags:     --no-owner --no-acl
```

### Dump all databases

```
Operation:       dump-all
Password File:   /root/.pgpass
Dump File:       /backups/all-databases_%Y-%m-%d.sql.gz
```

### Restore from a custom-format dump

```
Operation:        restore
Password File:    /root/.pgpass
Database:         myapp
Restore File:     /backups/myapp_2026-05-15.dump
Extra Flags:      --no-owner --clean
```

### Restore from a plain SQL dump

```
Operation:        restore
Password File:    /root/.pgpass
Database:         myapp
Restore File:     /backups/myapp_2026-05-15.sql
```

The plugin auto-detects `.sql` files and uses `psql` instead of `pg_restore`.

### Run a verification query

```
Operation:        query
Password File:    /root/.pgpass
Database:         myapp
Query:            SELECT schemaname, tablename, n_live_tup FROM pg_stat_user_tables ORDER BY n_live_tup DESC LIMIT 10;
```

### VACUUM ANALYZE

```
Operation:        vacuum
Password File:    /root/.pgpass
Database:         myapp
```

### Create a new database

```
Operation:          create-database
Password File:      /root/.pgpass
Database:           myapp_staging
```

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
