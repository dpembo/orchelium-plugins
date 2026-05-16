# MySQL / MariaDB Plugin

Run backups, restores, queries, and database management tasks against a MySQL or MariaDB server. Authentication is handled securely via an options/password file rather than command-line credentials.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `dump` | Export a database to a `.sql` or `.sql.gz` file using `mysqldump` |
| `restore` | Restore a database from a dump file |
| `query` | Run an arbitrary SQL statement |
| `list-databases` | List all databases on the server |
| `create-database` | Create a new database |
| `drop-database` | Drop (delete) a database |
| `check` | Check and repair all tables in a database using `mysqlcheck` |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `dump` | Operation to perform |
| **Host** | No | `localhost` | MySQL server hostname or IP |
| **Port** | No | `3306` | MySQL server port |
| **Username** | No | `root` | MySQL username |
| **Options / Password File** | Yes | — | Path to a MySQL options file containing credentials |
| **Database** | dump, restore, query, create/drop, check | Target database name |
| **Dump File Path** | dump | Destination file; supports `%Y-%m-%d` date placeholders |
| **Restore File Path** | restore | Path to the dump file to restore (`.sql` or `.sql.gz`) |
| **SQL Query** | query | The SQL statement to execute |
| **Extra Flags** | No | — | Any additional `mysqldump`/`mysql` flags |

---

## Options / Password File

Never put your password on the command line. Create a MySQL options file and protect it:

```ini
[client]
user     = backupuser
password = s3cr3t
```

```bash
chmod 600 /etc/mysql/backup.cnf
```

Then set **Options / Password File** to `/etc/mysql/backup.cnf`.

---

## Usage Examples

### Dump a database (compressed)

```
Operation:        dump
Host:             localhost
Username:         backupuser
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Dump File:        /backups/wordpress_%Y-%m-%d.sql.gz
Extra Flags:      --single-transaction --routines --events
```

The `%Y-%m-%d` placeholder is expanded to today's date automatically.

### Dump all databases

```
Operation:        dump
Options File:     /etc/mysql/backup.cnf
Database:         (leave blank for all databases)
Dump File:        /backups/all-databases_%Y-%m-%d.sql.gz
Extra Flags:      --all-databases --single-transaction
```

### Restore from a dump

```
Operation:        restore
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Restore File:     /backups/wordpress_2026-05-15.sql.gz
```

### Run a health-check query

```
Operation:        query
Options File:     /etc/mysql/backup.cnf
Database:         wordpress
Query:            SELECT COUNT(*) AS total_posts FROM wp_posts;
```

### Create a new database

```
Operation:         create-database
Options File:      /etc/mysql/backup.cnf
Database:          myapp_staging
```

### Check and repair tables

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
- The `check` operation calls `mysqlcheck`, which can also `--auto-repair` minor corruption.

---

## Requirements

- `mysql`, `mysqldump`, and `mysqlcheck` installed on the agent host
- MySQL/MariaDB server accessible from the agent
- Options file with valid credentials
