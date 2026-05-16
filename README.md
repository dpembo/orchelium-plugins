# orchelium-plugins

The official plugin repository for [Orchelium](https://github.com/dpembo/orchelium).

Plugins are self-contained directories that extend Orchelium with new node types — each plugin defines its inputs, the shell script that runs on the agent, an icon, and documentation.

## Available Plugins

| Plugin | Category | Description |
|--------|----------|-------------|
| [borg](./borg/) | backup | BorgBackup — deduplicated, compressed, encrypted backups |
| [docker](./docker/) | containers | Docker — start, stop, exec, pull, logs, prune, and more |
| [lxc-pct](./lxc-pct/) | containers | Proxmox LXC containers via the `pct` CLI |
| [mount](./mount/) | storage | Mount / unmount NFS, SMB, LUKS, loop, bind, and tmpfs |
| [mysql](./mysql/) | databases | MySQL / MariaDB backup, restore, and management |
| [postgresql](./postgresql/) | databases | PostgreSQL backup, restore, and management |
| [proxmox-backup](./proxmox-backup/) | backup | Proxmox VM / LXC backup via `vzdump` |
| [rclone](./rclone/) | file-sync | Rclone — sync to/from S3, GDrive, Dropbox, SFTP, and more |
| [restic](./restic/) | backup | Restic — deduplicated backups to any supported backend |
| [rsync](./rsync/) | file-sync | Rsync — file sync over SSH or locally |
| [s3](./s3/) | file-sync | S3 object storage via the AWS CLI |
| [sqlite](./sqlite/) | databases | SQLite backup, restore, and queries |
| [truenas](./truenas/) | storage | TrueNAS CORE/SCALE via the REST API |
| [zfs-send-receive](./zfs-send-receive/) | storage | ZFS dataset replication via `zfs send \| zfs receive` |
| [zfs-snapshot](./zfs-snapshot/) | storage | ZFS snapshot create, destroy, rollback, and clone |

## Plugin Structure

Each plugin is a directory containing:

```
<plugin-name>/
├── plugin.yaml   # Required — metadata, inputs, and command/template definition
├── run.sh        # Required — the script executed on the agent
├── icon.svg      # Optional — displayed in the Orchelium UI
└── docs.md       # Optional — shown in the Plugin Manager detail panel
```

The `plugin.yaml` format is documented in the [Orchelium developer guide](https://github.com/dpembo/orchelium/blob/main/docs/Developers/developer-guide.md).

## Installing Plugins

Plugins are managed from the **Plugin Manager** in the Orchelium UI (user profile menu → Plugin Manager). You can also install manually by copying a plugin directory into your Orchelium `plugins/` folder — the registry hot-reloads automatically.

## Contributing

See [CONTRIBUTING.md](./CONTRIBUTING.md) for how to submit a new plugin or report an issue with an existing one.

## License

MIT — see [LICENSE](./LICENSE).
