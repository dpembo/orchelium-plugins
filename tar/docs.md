# Tar Archive Plugin

Create, extract, or list tar archives using the standard `tar` command.
No extra dependencies required — `tar` is available on every Linux and
macOS system.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `create` | Bundle one or more files/directories into a new archive |
| `extract` | Unpack an existing archive, optionally to a specific directory |
| `list` | List the contents of an archive without extracting |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `create` | The action to perform |
| **Archive Path** | Yes | — | Path to the `.tar` / `.tar.gz` / etc. file |
| **Source Path(s)** | For `create` | — | Space-separated files or directories to archive |
| **Extract Destination** | No | CWD | Directory to extract into (`extract` only) |
| **Compression** | No | `auto` | Algorithm: `auto`, `none`, `gzip`, `bzip2`, `xz`, `zstd` |
| **Exclude Pattern(s)** | No | — | Space-separated globs: `*.log *.tmp .cache` |
| **Extra tar Flags** | No | — | Raw flags passed directly to tar |

### Compression auto-detection

When compression is set to `auto` (the default), the archive file extension
determines the algorithm:

| Extension | Algorithm |
|-----------|-----------|
| `.tar.gz`, `.tgz` | gzip |
| `.tar.bz2`, `.tbz2` | bzip2 |
| `.tar.xz`, `.txz` | xz |
| `.tar.zst`, `.tzst` | zstd |
| `.tar` | none |

---

## Usage Examples

```yaml
# Create a gzip-compressed backup of /var/data
operation: create
archive: /backup/data-2024-01-15.tar.gz
source: /var/data/

# Create with exclusions
operation: create
archive: /backup/app.tar.gz
source: /opt/myapp/
exclude: "*.log *.tmp node_modules"

# Extract to a specific directory
operation: extract
archive: /backup/data-2024-01-15.tar.gz
destination: /restore/data/

# List contents of an archive
operation: list
archive: /backup/app.tar.gz

# Multiple source paths, zstd compression
operation: create
archive: /backup/configs.tar.zst
source: "/etc/nginx/ /etc/postgresql/"
exclude: "*.pid"
```
