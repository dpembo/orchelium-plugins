# Tar Archive Plugin

Create, extract, or list tar archives using the standard `tar` command.
No extra dependencies required — `tar` is available on every Linux and macOS system.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Archive Path** | Path to the `.tar` / `.tar.gz` / etc. file |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Compression** | Algorithm: `auto`, `none`, `gzip`, `bzip2`, `xz`, `zstd` |
| **Exclude Pattern(s)** | Space-separated globs: `*.log *.tmp .cache` |
| **Extra tar Flags** | Raw flags passed directly to tar |

---

## Compression auto-detection

When compression is set to `auto` (the default), the archive file extension determines the algorithm:

| Extension | Algorithm |
|-----------|-----------|
| `.tar.gz`, `.tgz` | gzip |
| `.tar.bz2`, `.tbz2` | bzip2 |
| `.tar.xz`, `.txz` | xz |
| `.tar.zst`, `.tzst` | zstd |
| `.tar` | none |

---

## create — Bundle Files into a New Archive

Bundle one or more files/directories into a new archive.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Archive Path** | Yes | Path to the output `.tar` / `.tar.gz` / etc. file |
| **Source Path(s)** | Yes | Space-separated files or directories to archive |
| **Compression** | No | Algorithm (default: `auto`) |
| **Exclude Pattern(s)** | No | Space-separated glob patterns to skip |
| **Extra tar Flags** | No | Raw flags passed directly to tar |

### Example

```
Operation:    create
Archive:      /backup/data-2026-01-15.tar.gz
Source:       /var/data/
Compression:  auto
```

---

## extract — Unpack an Existing Archive

Unpack an existing archive, optionally to a specific directory.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Archive Path** | Yes | Path to the input archive file |
| **Extract Destination** | No | Directory to extract into (default: current directory) |
| **Compression** | No | Algorithm (default: `auto`) |
| **Extra tar Flags** | No | Raw flags passed directly to tar |

### Example

```
Operation:       extract
Archive:         /backup/data-2026-01-15.tar.gz
Destination:     /restore/data/
Compression:     auto
```

---

## list — List Archive Contents

List the contents of an archive without extracting.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Archive Path** | Yes | Path to the archive file |
| **Compression** | No | Algorithm (default: `auto`) |
| **Extra tar Flags** | No | Raw flags passed directly to tar |

### Example

```
Operation:    list
Archive:      /backup/app.tar.gz
Compression:  auto
```

---

## Tips

- The `auto` compression detection works by file extension—make sure your archive has the right extension (e.g. `.tar.gz` for gzip).
- To create multiple source paths, separate them with spaces: `/etc/nginx/ /etc/postgresql/ /var/www`
- Use exclude patterns to avoid backing up logs, caches, or temporary files: `*.log *.tmp node_modules`
- Tar preserves file permissions and ownership by default; use `--no-same-permissions` in Extra Flags if restoring to a different user.

---

## Requirements

- `tar` command installed (available on all Linux and macOS systems)
