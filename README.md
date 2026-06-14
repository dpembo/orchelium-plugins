# orchelium-plugins

The official plugin repository for [Orchelium](https://github.com/dpembo/orchelium).

Plugins are self-contained directories that extend Orchelium with new node types — each plugin defines its inputs, the shell script that runs on the agent, an icon, and documentation.

## Available Plugins

| Plugin | Version | Category | Description |
|--------|---------|----------|-------------|
| [bitwarden](./bitwarden/) | 1.1.0 | tools | Export a Bitwarden organisation vault to a password-protected ZIP |
| [borg](./borg/) | 2.1.0 | backup | BorgBackup — deduplicated, compressed, encrypted backups |
| [docker](./docker/) | 2.1.0 | containers | Docker — start, stop, exec, pull, logs, prune, and more |
| [file-prune](./file-prune/) | 1.1.0 | system | Delete files by age and wildcard pattern; useful for log rotation |
| [lxc-pct](./lxc-pct/) | 2.1.0 | containers | Proxmox LXC containers — start, stop, snapshot, clone, exec |
| [mount](./mount/) | 2.1.0 | storage | Mount/unmount NFS, CIFS/SMB, LUKS, loop, bind, and tmpfs |
| [mysql](./mysql/) | 2.1.0 | databases | MySQL/MariaDB — dump, restore, query, backup, check, manage |
| [opnsense](./opnsense/) | 2.2.0 | network | OPNsense firewall — backups, rules, aliases, NAT, diagnostics |
| [paperless-ngx](./paperless-ngx/) | 2.1.0 | backup | Paperless-ngx document library backup and export |
| [postgresql](./postgresql/) | 2.1.0 | databases | PostgreSQL — dump, restore, query, backup, maintenance |
| [proxmox-backup](./proxmox-backup/) | 1.1.3 | backup | Proxmox VM/LXC backup via `vzdump` |
| [rclone](./rclone/) | 2.1.0 | storage | Rclone — sync to/from S3, GDrive, Dropbox, SFTP, and more |
| [restic](./restic/) | 2.1.0 | backup | Restic — deduplicated backups to any supported backend |
| [rsync](./rsync/) | 1.1.1 | backup | Rsync — file sync over SSH or locally with verification |
| [s3](./s3/) | 2.1.0 | storage | S3 object storage — sync, upload, download, list, delete |
| [sqlite](./sqlite/) | 2.1.0 | databases | SQLite — backup, restore, query, vacuum, integrity check |
| [systemd](./systemd/) | 1.1.1 | system | Systemd services — start, stop, restart, enable, disable, status |
| [tar](./tar/) | 2.1.0 | archiving | Tar archives — create, extract, list with optional compression |
| [truenas](./truenas/) | 2.1.0 | storage | TrueNAS — snapshots, replication, cloud sync, scrubs |
| [wake-on-lan](./wake-on-lan/) | 1.1.0 | network | Wake-on-LAN (WoL) magic packet to wake sleeping machines |
| [zfs-send-receive](./zfs-send-receive/) | 2.1.0 | storage | ZFS dataset replication via `zfs send \| zfs receive` |
| [zfs-snapshot](./zfs-snapshot/) | 2.1.0 | storage | ZFS snapshots — create, destroy, list, send, rollback, clone |

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
