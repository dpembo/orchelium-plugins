# File Prune

Delete files matching a wildcard pattern that are older than a specified number of days. Useful for enforcing retention policies on backup archives, log files, database dumps, or any time-stamped files.

## Inputs

| Name | Type | Required | Default | Description |
|---|---|---|---|---|
| `directory` | string | Yes | — | Full path to the directory to prune |
| `pattern` | string | Yes | — | Shell wildcard pattern (e.g. `*.tar.gz`) |
| `age_days` | number | Yes | `30` | Delete files older than this many days |
| `dry_run` | boolean | No | `false` | List files without deleting them |
| `recursive` | boolean | No | `false` | Search subdirectories as well |

## Outputs

| Name | Description |
|---|---|
| `success` | `true` if the operation completed without errors |
| `deleted_count` | Number of files deleted (or matched in dry-run mode) |

## How it works

The plugin calls `find` with `-mtime +<age_days>` to locate files matching the pattern. By default only the top-level directory is searched (`-maxdepth 1`). When `recursive` is enabled, subdirectories are included.

In **dry-run mode** the matching files are listed but nothing is deleted. Use this to validate your pattern and age threshold before committing to deletion.

## Common patterns

| Pattern | Matches |
|---|---|
| `*.tar.gz` | Compressed tar archives |
| `*.zip` | Zip archives |
| `*.log` | Log files |
| `backup-*` | Files whose name starts with `backup-` |
| `db_dump_*` | Database dump files |

## Example: prune old nightly backup archives

```yaml
plugin: file-prune
inputs:
  directory: /mnt/backups/nightly
  pattern: "*.tar.gz"
  age_days: 30
  dry_run: false
  recursive: false
```

## Example: dry-run first, then delete

Run with `dry_run: true` to review what will be removed, then set it to `false` for the real run. The `deleted_count` output is available to downstream steps in both modes.

## Notes

- The agent user must have **read and write** access to the target directory.
- Only regular files are matched (`-type f`). Directories and symlinks are never deleted.
- The `age_days` threshold is based on the file's **last-modified time** (`mtime`), not creation time.
- An age of `0` would match files modified more than 0 days ago (i.e. not today). Use `1` to keep today's files.
