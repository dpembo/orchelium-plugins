# MySQL / MariaDB Plugin

Run backups, restores, queries, and database management tasks against a MySQL or MariaDB server. Authentication is handled securely via an options/password file rather than command-line credentials.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Options / Password File** | Path to a MySQL options file containing credentials |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Host** | MySQL server hostname or IP (default: `localhost`) |
| **Port** | MySQL server port (default: `3306`) |
| **Username** | MySQL username (default: `root`) |

---

### Options / Password File Format

Never put credentials on the command line. Create a MySQL options file and protect it:

```ini
[client]
user     = backupuser
password = s3cr3t
```

```bash
chmod 600 /etc/mysql/backup.cnf
```

---

## dump — Export a Database to a SQL File

Export a database to a `.sql` or `.sql.gz` file using `mysqldump`.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Database name to dump |
| **Dump File Path** | Yes | Destination file; supports `%Y-%m-%d` date placeholders |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |
| **Extra Flags** | No | Additional `mysqldump` flags |

### Example

```
Operation:        dump
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Dump File:        /backups/wordpress_%Y-%m-%d.sql.gz
Extra Flags:      --single-transaction --routines --events
```

---

## restore — Restore a Database from a Dump File

Restore a database from a dump file (`.sql` or `.sql.gz`).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Target database name |
| **Restore File Path** | Yes | Path to the dump file (`.sql` or `.sql.gz`) |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        restore
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Restore File:     /backups/wordpress_2026-05-15.sql.gz
```

---

## query — Execute an Arbitrary SQL Statement

Run an arbitrary SQL statement and return results.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Target database |
| **SQL Query** | Yes | The SQL statement to execute |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |

### Example

```
Operation:        query
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Query:            SELECT COUNT(*) AS total_posts FROM wp_posts;
```

---

## list-databases — List All Databases

List all databases on the server.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |

### Example

```
Operation:        list-databases
Options File:     /etc/mysql/backup.cnf
```

---

## create-database — Create a New Database

Create a new database (IF NOT EXISTS).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Name of the new database |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |

### Example

```
Operation:        create-database
Options File:     /etc/mysql/backup.cnf
Database:         myapp_staging
```

---

## drop-database — Drop (Delete) a Database

Drop (delete) an existing database. **Warning: This is irreversible!**

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Name of the database to drop |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |

### Example

```
Operation:        drop-database
Options File:     /etc/mysql/backup.cnf
Database:         old_staging
```

---

## check — Check and Repair Database Tables

Run `mysqlcheck --auto-repair` on a database.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Options / Password File** | Yes | Path to MySQL options file |
| **Database** | Yes | Database to check |
| **Host** | No | MySQL server hostname |
| **Port** | No | MySQL server port |
| **Username** | No | MySQL username |
| **Extra Flags** | No | Additional flags |

### Example

```
Operation:        check
Options File:     /etc/mysql/backup.cnf
Database:         myapp
Extra Flags:      --auto-repair
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

Example: `/backups/mydb_%Y-%m-%d_%H%M%S.sql.gz`

---

## Tips

- Always use `--single-transaction` for InnoDB databases to get a consistent snapshot without locking tables.
- Include `--routines --events` to also dump stored procedures, functions, and events.
- Use `--hex-blob` to safely dump binary columns.
- For very large databases, consider splitting by table or using `mydumper` for parallel exports.
- The `check` operation can also `--auto-repair` minor corruption.

---

## Requirements

- `mysql`, `mysqldump`, and `mysqlcheck` installed on the agent host
- MySQL/MariaDB server accessible from the agent
- Options file with valid credentials
