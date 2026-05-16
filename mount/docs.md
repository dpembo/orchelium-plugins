# Mount / Unmount Plugin

Mount or unmount filesystems on the agent host. Supports NFS, CIFS/SMB, standard block devices, disk images (loop), LUKS encrypted volumes, bind mounts, tmpfs, and auto-detection.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `mount` | Mount a filesystem at the specified target |
| `unmount` | Unmount a mounted filesystem |
| `remount` | Unmount then re-mount (useful to apply new options) |
| `status` | Check if a path is currently mounted |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Operation** | Yes | — | Operation to perform |
| **Mount Type** | mount, remount | Type of filesystem; `auto` for kernel detection |
| **Source** | mount, remount | Device, network path, or image file to mount |
| **Mount Point** | Yes | All | Directory where the filesystem should be attached |
| **Mount Options** | No | mount, remount | Comma-separated options, e.g. `ro,noatime` |
| **CIFS Credentials File** | No | mount (cifs) | Path to a credentials file (`username=...` / `password=...`) |
| **LUKS Mapper Name** | mount (luks) | Device mapper name, e.g. `backup-crypt` |
| **LUKS Key File** | mount (luks) | Path to the LUKS unlock key file |
| **Create Mount Point if Missing** | No | `yes` | Create the target directory if it does not exist |
| **Lazy Unmount (-l)** | No | `no` | Detach filesystem from namespace even if busy |
| **Force Unmount (-f)** | No | `no` | Force unmount (use with NFS when server is unreachable) |

---

## Mount Types

| Type | Description |
|------|-------------|
| `auto` | Let the kernel detect the filesystem type |
| `nfs` | Network File System (requires `nfs-common`) |
| `cifs` | Windows/Samba share (requires `cifs-utils`) |
| `ext4`, `xfs`, `btrfs`, `vfat` | Standard block device filesystems |
| `luks` | Encrypted LUKS volume — unlocks with a key file before mounting |
| `loop` | Disk image file (`.img`, `.iso`) |
| `bind` | Bind-mount a directory to another location |
| `tmpfs` | In-memory temporary filesystem |

---

## Usage Examples

### Mount an NFS share

```
Operation:     mount
Mount Type:    nfs
Source:        192.168.1.20:/exports/backups
Mount Point:   /mnt/backup
Options:       rw,noatime,rsize=131072,wsize=131072
```

### Mount a CIFS/SMB share

```
Operation:           mount
Mount Type:          cifs
Source:              //192.168.1.10/backups
Mount Point:         /mnt/nas-backup
Credentials File:    /etc/samba/backup-credentials
Options:             uid=1000,gid=1000,file_mode=0660,dir_mode=0770
```

CIFS credentials file format:
```
username=backupuser
password=s3cr3t
domain=WORKGROUP
```

### Mount a LUKS encrypted disk

```
Operation:        mount
Mount Type:       luks
Source:           /dev/sdb1
Mount Point:      /mnt/secure-backup
LUKS Name:        backup-crypt
LUKS Key File:    /etc/luks/backup.key
```

### Mount a disk image

```
Operation:      mount
Mount Type:     loop
Source:         /var/images/backup.img
Mount Point:    /mnt/backup-img
```

### Unmount

```
Operation:      unmount
Mount Point:    /mnt/backup
```

### Check if mounted

```
Operation:      status
Mount Point:    /mnt/backup
```

### Remount read-only

```
Operation:      remount
Mount Type:     auto
Source:         /dev/sdb1
Mount Point:    /mnt/backup
Options:        ro,noatime
```

---

## Tips

- Use `Mount / Unmount` nodes around your backup steps: mount before backup, unmount after.
- For NFS, use `noatime` and large `rsize`/`wsize` values (e.g. `131072`) for best performance.
- For CIFS, store credentials in a file with `chmod 600` rather than embedding in the options field.
- Lazy unmount (`-l`) is useful when a process holds the mount open briefly; it detaches from the namespace immediately and finishes cleanup when the last file handle is closed.
- The `status` operation exits with code `0` if mounted, `1` if not — useful as a pre-condition check in your orchestration.

---

## Requirements

- Agent must run as root (or with `sudo` permissions for `mount`/`umount`)
- Required packages: `nfs-common` (NFS), `cifs-utils` (CIFS), `cryptsetup` (LUKS)
