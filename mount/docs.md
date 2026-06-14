# Mount / Unmount Plugin

Mount or unmount filesystems on the agent host. Supports NFS, CIFS/SMB, standard block devices, disk images (loop), LUKS encrypted volumes, bind mounts, tmpfs, and auto-detection.

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Mount Point** | Directory where the filesystem should be attached |

---

## mount — Mount a Filesystem

Mount a filesystem at the specified target.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Mount Point** | Yes | Directory where the filesystem will be attached |
| **Mount Type** | No | Type of filesystem; `auto` for kernel detection |
| **Source** | Yes | Device, network path, or image file to mount |
| **Mount Options** | No | Comma-separated options, e.g. `ro,noatime` |
| **CIFS Credentials File** | No | Path to a credentials file (for CIFS only) |
| **LUKS Mapper Name** | No | Device mapper name, e.g. `backup-crypt` (for LUKS only) |
| **LUKS Key File** | No | Path to the LUKS unlock key file (for LUKS only) |
| **Create Mount Point if Missing** | No | Create the target directory if it does not exist |

### Example

```
Operation:     mount
Mount Type:    nfs
Source:        192.168.1.20:/exports/backups
Mount Point:   /mnt/backup
Options:       rw,noatime,rsize=131072,wsize=131072
```

---

## unmount — Unmount a Mounted Filesystem

Unmount a mounted filesystem.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Mount Point** | Yes | Directory to unmount |
| **Lazy Unmount (-l)** | No | Detach filesystem even if busy |
| **Force Unmount (-f)** | No | Force unmount (use with unreachable NFS servers) |

### Example

```
Operation:      unmount
Mount Point:    /mnt/backup
Lazy Unmount:   no
Force Unmount:  no
```

---

## remount — Unmount and Re-mount with New Options

Unmount then re-mount (useful to apply new options).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Mount Point** | Yes | Directory to remount |
| **Mount Type** | No | Type of filesystem |
| **Source** | Yes | Device, network path, or image file |
| **Mount Options** | No | Comma-separated options |
| **CIFS Credentials File** | No | Path to a credentials file (for CIFS only) |
| **LUKS Mapper Name** | No | Device mapper name (for LUKS only) |
| **LUKS Key File** | No | Path to the LUKS unlock key file (for LUKS only) |

### Example

```
Operation:      remount
Mount Type:     auto
Source:         /dev/sdb1
Mount Point:    /mnt/backup
Options:        ro,noatime
```

---

## status — Check if a Path is Currently Mounted

Check whether a path is currently mounted.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Mount Point** | Yes | Directory to check |

### Example

```
Operation:      status
Mount Point:    /mnt/backup
```

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

### CIFS Credentials File Format

```
username=backupuser
password=s3cr3t
domain=WORKGROUP
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
