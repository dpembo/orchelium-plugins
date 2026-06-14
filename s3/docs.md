# S3 Object Storage Plugin

Interact with Amazon S3 or any S3-compatible object store using the AWS CLI. Supports syncing directories, uploading and downloading files, listing objects, deleting keys, creating buckets, and generating pre-signed URLs.

Compatible with: **AWS S3**, **MinIO**, **Wasabi**, **Cloudflare R2**, **Backblaze B2 (S3 API)**, **DigitalOcean Spaces**, and any other S3-compatible service.

---

## Common Parameters

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **AWS Credentials File** | Path to an AWS credentials file (default: `~/.aws/credentials`) |
| **AWS Profile** | Named profile within the credentials file (default: `default`) |
| **AWS Region** | AWS region (e.g. `us-east-1`) |
| **Endpoint URL** | Custom endpoint for non-AWS services |
| **Dry Run** | Simulate without making changes (`yes`/`no`) |

### Authentication

Credentials are **never** passed on the command line. The plugin reads them (in order of priority):

1. **Credentials File** field → sets `AWS_SHARED_CREDENTIALS_FILE`
2. **Profile** field → sets `AWS_PROFILE`
3. Agent environment variables: `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY`
4. IAM instance role / container credentials (EC2 / ECS)

#### Credentials File Format

```ini
[default]
aws_access_key_id     = AKIAIOSFODNN7EXAMPLE
aws_secret_access_key = wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
```

```bash
chmod 600 /etc/aws/backup-credentials
```

---

## sync — Synchronise a Local Directory to/from S3

Make destination identical to source (transfers only changed files).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | Yes | Object key prefix (path within the bucket) |
| **Local Path** | Yes | Local file or directory |
| **Delete Extra Files** | No | Remove S3 objects that no longer exist in source (`yes`/`no`) |
| **Exclude Patterns** | No | Space-separated glob patterns to skip |
| **Include Patterns** | No | Space-separated glob patterns to include |
| **Storage Class** | No | S3 storage class for uploads (default: `STANDARD`) |
| **Extra Flags** | No | Any additional AWS CLI flags |

### Example

```
Operation:       sync
Bucket:          my-backup-bucket
Prefix:          databases/
Local Path:      /var/backups/databases
Credentials:     /etc/aws/backup-credentials
Delete:          yes
```

---

## upload — Upload a File or Directory to S3

Upload one or more files to S3.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | Yes | Object key prefix |
| **Local Path** | Yes | Local file or directory |
| **Storage Class** | No | S3 storage class (default: `STANDARD`) |
| **Exclude Patterns** | No | Space-separated glob patterns to skip |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:       upload
Bucket:          my-backup-bucket
Prefix:          dumps/mydb_2026-05-16.sql.gz
Local Path:      /backups/mydb_2026-05-16.sql.gz
Credentials:     /etc/aws/backup-credentials
Storage Class:   STANDARD_IA
```

---

## download — Download an Object or Prefix from S3

Download one or more objects from S3 to a local path.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | Yes | Object key prefix |
| **Local Path** | Yes | Local destination path |
| **Exclude Patterns** | No | Space-separated glob patterns to skip |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:       download
Bucket:          my-backup-bucket
Prefix:          dumps/mydb_2026-05-16.sql.gz
Local Path:      /tmp/restore/mydb.sql.gz
Credentials:     /etc/aws/backup-credentials
```

---

## ls — List Objects in a Bucket or Prefix

List objects in a bucket or prefix.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | No | Object key prefix to filter |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:    ls
Bucket:       my-backup-bucket
Prefix:       databases/
Credentials:  /etc/aws/backup-credentials
```

---

## delete — Delete an Object or Prefix

Delete an object or all objects under a prefix.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | Yes | Object key or prefix to delete |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:    delete
Bucket:       my-backup-bucket
Prefix:       dumps/mydb_2026-04-01.sql.gz
Credentials:  /etc/aws/backup-credentials
```

A prefix ending in `/` automatically triggers recursive deletion.

---

## mb — Create a New Bucket

Create a new S3 bucket.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | New bucket name |
| **AWS Region** | No | Region for the new bucket |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:    mb
Bucket:       my-new-backup-bucket
Region:       us-east-1
```

---

## presign — Generate a Pre-Signed Download URL

Generate a temporary pre-signed download URL for secure, time-limited access.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Bucket** | Yes | S3 bucket name |
| **S3 Prefix / Key** | Yes | Object key |
| **Presign Expiry (seconds)** | No | Validity period (default: `3600`) |
| **Extra Flags** | No | Additional AWS CLI flags |

### Example

```
Operation:        presign
Bucket:           my-backup-bucket
Prefix:           dumps/mydb_2026-05-16.sql.gz
Credentials:      /etc/aws/backup-credentials
Presign Expiry:   86400
```

The URL is printed to the output and can be shared for secure, time-limited access without AWS credentials.

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

MinIO requires a region value even though it is not used — `us-east-1` works universally.

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
