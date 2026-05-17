# Bitwarden Export Plugin

Export a Bitwarden organisation vault to a password-protected ZIP file.
Authenticates using the Bitwarden API key (no interactive login required)
and produces a ZIP-encrypted file suitable for secure off-site storage.

---

## Requirements

- **Bitwarden CLI (`bw`)** installed on the agent host.
  - Debian/Ubuntu: `npm install -g @bitwarden/cli` or download the binary
    from [bitwarden.com/help/cli](https://bitwarden.com/help/cli/)
  - The `bw` binary must be in `$PATH`.
- **7-Zip (`7z`)** — recommended for AES-256 encrypted ZIP output.
  - `apt install p7zip-full` / `dnf install p7zip-plugins`
  - Falls back to `zip` (ZipCrypto) if 7z is not available.
- **`python3`** — for input parsing (pre-installed on most Linux systems).
- The authenticating account must have **admin/owner access** to the
  organisation to perform a vault export.

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Organization ID** | Yes | — | UUID of the Bitwarden organisation |
| **API Client ID** | Yes | — | `organization.xxxxxxxx` from Organisation API Key settings |
| **API Client Secret** | Yes | — | Client secret paired with the client ID |
| **Master Password** | Yes | — | Vault master password (never logged or written to disk) |
| **ZIP Encryption Password** | Yes | — | Password for the output ZIP file |
| **Export Format** | No | `csv` | `csv`, `json`, or `encrypted_json` |
| **Output ZIP Path** | No | `/tmp/bw-export-<timestamp>.zip` | Full path for the output file |
| **Server URL** | No | `https://vault.bitwarden.com` | Override for self-hosted instances |

### Export formats

| Format | Description |
|--------|-------------|
| `csv` | Plaintext CSV — widely compatible with password managers and spreadsheet tools |
| `json` | Plaintext JSON — full fidelity, includes all custom fields |
| `encrypted_json` | Bitwarden-encrypted JSON — requires master password to read; safe to store without additional encryption |

---

## Security notes

- Credentials are passed only via **environment variables** inside the script — never on a command line where they could appear in `ps` output.
- The plaintext export file is written to a hidden temp path and **deleted immediately** after the ZIP is created, even if the script fails.
- `bw logout` is called automatically on exit (success and error paths).
- **AES-256** encryption is used when 7-Zip is available (strongly recommended). The fallback `zip` uses the weaker legacy ZipCrypto algorithm.
- The output ZIP password is not logged anywhere.

---

## Usage Examples

```yaml
# Export organisation vault as CSV, write ZIP to /backup/
organization_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_id: "organization.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
client_secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
master_password: "MyMasterPassword"
zip_password: "StrongZipPassphrase123!"
format: csv
output_path: "/backup/bitwarden/vault-export.zip"

# Export as JSON from a self-hosted Vaultwarden instance
organization_id: "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
client_id: "organization.xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
client_secret: "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
master_password: "MyMasterPassword"
zip_password: "StrongZipPassphrase123!"
format: json
server_url: "https://vaultwarden.internal.example.com"
output_path: "/backup/bitwarden/vault-export.zip"
```

---

## Getting your API credentials

1. Log in to the Bitwarden web vault.
2. Go to your **Organisation → Settings → API Key**.
3. Click **View API Key** (requires master password confirmation).
4. Copy the **Client ID** and **Client Secret**.

Your **Organisation ID** is shown on the same settings page, or can be
found in the URL: `https://vault.bitwarden.com/#/organizations/<org-id>/settings`.
