# S3 Object Storage Plugin

Interact with Amazon S3 or any S3-compatible object store using the AWS CLI. Supports syncing directories, uploading and downloading files, listing objects, deleting keys, creating buckets, and generating pre-signed URLs.

Compatible with: **AWS S3**, **MinIO**, **Wasabi**, **Cloudflare R2**, **Backblaze B2 (S3 API)**, **DigitalOcean Spaces**, and any other S3-compatible service.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `sync` | Synchronise a local directory to/from an S3 prefix (transfers only changed files) |
| `upload` | Upload a file or directory to S3 |
| `download` | Download an object or prefix from S3 to a local path |
| `ls` | List objects in a bucket or prefix |
| `delete` | Delete an object or all objects under a prefix |
| `mb` | Create a new bucket |
| `presign` | Generate a temporary pre-signed download URL |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `sync` | Operation to perform |
| **Bucket** | Most operations | — | S3 bucket name |
| **S3 Prefix / Key** | No | — | Object key or path prefix within the bucket |
| **Local Path** | sync, upload, download | — | Local file or directory |
| **AWS Credentials File** | No | `~/.aws/credentials` | Path to an AWS credentials file |
| **AWS Profile** | No | `default` | Named profile within the credentials file |
| **AWS Region** | No | — | AWS region (e.g. `us-east-1`). Often not needed for S3-compatible services |
| **Endpoint URL** | No | — | Custom endpoint for non-AWS services (e.g. `https://s3.wasabisys.com`) |
| **Storage Class** | No | `STANDARD` | S3 storage class for uploads |
| **Delete Extra Files** | No | `no` | Remove S3 objects that no longer exist in source (sync only) |
| **Dry Run** | No | `no` | Simulate without making changes |
| **Exclude Patterns** | No | — | Space-separated glob patterns to skip |
| **Include Patterns** | No | — | Space-separated glob patterns to include (applied after excludes) |
| **Presign Expiry (seconds)** | No | `3600` | Validity period for pre-signed URLs |
| **Extra Flags** | No | — | Any additional AWS CLI flags |

---

## Authentication

Credentials are **never** passed on the command line. Instead, the plugin reads them from (in order of priority):

1. **Credentials File** field → sets `AWS_SHARED_CREDENTIALS_FILE`
2. **Profile** field → sets `AWS_PROFILE`
3. Agent environment variables: `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
4. IAM instance role / container credentials (EC2 / ECS)

### Credentials file format

```ini
[default]
aws_access_key_id     = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

```bash
chmod 600 /etc/aws/backup-credentials
```

---

## Usage Examples

### Sync local backups to S3

```
Operation:       sync
Bucket:          my-backup-bucket
Prefix:          databases/
Local Path:      /var/backups/databases
Credentials:     /etc/aws/backup-credentials
Delete:          yes
```

### Upload a single compressed dump

```
Operation:       upload
Bucket:          my-backup-bucket
Prefix:          dumps/mydb_2026-05-16.sql.gz
Local Path:      /backups/mydb_2026-05-16.sql.gz
Credentials:     /etc/aws/backup-credentials
Storage Class:   STANDARD_IA
```

### Download a backup file

```
Operation:       download
Bucket:          my-backup-bucket
Prefix:          dumps/mydb_2026-05-16.sql.gz
Local Path:      /tmp/restore/mydb.sql.gz
Credentials:     /etc/aws/backup-credentials
```

### List objects under a prefix

```
Operation:    ls
Bucket:       my-backup-bucket
Prefix:       databases/
Credentials:  /etc/aws/backup-credentials
```

### Delete a specific object

```
Operation:    delete
Bucket:       my-backup-bucket
Prefix:       dumps/mydb_2026-04-01.sql.gz
Credentials:  /etc/aws/backup-credentials
```

### Delete all objects under a prefix

```
Operation:    delete
Bucket:       my-backup-bucket
Prefix:       old-backups/
Credentials:  /etc/aws/backup-credentials
```

> A prefix ending in `/` automatically triggers a recursive delete.

### Generate a pre-signed download URL

```
Operation:        presign
Bucket:           my-backup-bucket
Prefix:           dumps/mydb_2026-05-16.sql.gz
Credentials:      /etc/aws/backup-credentials
Presign Expiry:   86400
```

The URL is printed to the output and can be shared for secure, time-limited access without AWS credentials.

---

## Using with S3-Compatible Services

Set the **Endpoint URL** to point at any S3-compatible service:

| Service | Endpoint URL |
|---------|-------------|
| MinIO (local) | `http://minio:9000` or `http://192.168.1.10:9000` |
| Wasabi | `https://s3.wasabisys.com` |
| Cloudflare R2 | `https://<account-id>.r2.cloudflarestorage.com` |
| Backblaze B2 | `https://s3.us-west-004.backblazeb2.com` |
| DigitalOcean Spaces | `https://nyc3.digitaloceanspaces.com` |

Example (MinIO):

```
Operation:       sync
Bucket:          backups
Prefix:          databases/
Local Path:      /var/backups
Endpoint URL:    http://192.168.1.20:9000
Credentials:     /etc/minio/credentials
Region:          us-east-1
```

> MinIO requires a region value even though it is not used — `us-east-1` works universally.

---

## Storage Classes

| Class | Description |
|-------|-------------|
| `STANDARD` | Default; frequent access |
| `STANDARD_IA` | Infrequent access; lower cost, retrieval fee |
| `INTELLIGENT_TIERING` | Auto-moves between tiers based on access patterns |
| `GLACIER_IR` | Instant retrieval archival — seconds |
| `GLACIER` | Archival — minutes to hours retrieval |
| `DEEP_ARCHIVE` | Cheapest long-term archival — hours retrieval |

---

## Tips

- Use `sync` + `delete: yes` to keep an S3 prefix as an exact mirror of a local directory.
- Combine with a **MySQL** or **PostgreSQL** plugin node upstream to dump then upload in sequence.
- Pre-signed URLs expire automatically — use `presign` to share a backup file securely without exposing credentials.
- For very large uploads, add `--multipart-threshold 64MB --multipart-chunksize 16MB` to Extra Flags for parallel chunk uploads.
- Use `--no-progress` in Extra Flags to suppress progress bars in log output.

---

## Requirements

- AWS CLI v2 installed on the agent host (`aws --version`)
- Valid credentials accessible via file, profile, or environment
