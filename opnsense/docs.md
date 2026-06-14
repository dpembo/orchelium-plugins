# OPNsense Firewall Plugin

Query and manage OPNsense firewall configurations, backups, and diagnostics using the OPNsense REST API.

This plugin provides comprehensive access to OPNsense system management including:
- **Backup & Restore** — Download full configuration backups
- **Firmware Management** — Check firmware status and configuration
- **Firewall Rules** — List and query filter rules, aliases, and NAT rules
- **Diagnostics** — Access firewall logs, system info, and interface statistics
- **System Status** — Get real-time system health and status information

---

## Common Parameters

All operations require:

| Parameter | Description |
|-----------|-------------|
| **Host** | IP address or hostname of OPNsense firewall |
| **API Key** | OPNsense API key (from System → API → Keys) |
| **API Secret** | OPNsense API secret (paired with API key) |

Optional for all operations:

| Parameter | Description |
|-----------|-------------|
| **Verify SSL** | Whether to verify SSL certificate (default: no) |
| **Output Format** | Format output as JSON, CSV, or raw (default: JSON) |

---

## backup-get — List Available Backups

Retrieves list of available configuration backups with metadata.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    backup-get
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## backup-download — Download Configuration Backup

Downloads a full OPNsense configuration backup as XML. Optionally specify a backup ID; if not specified, downloads the most recent.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Backup ID** | No | Specific backup to download (optional; uses latest if empty) |

### Example

```
Operation:    backup-download
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
Backup ID:    (leave empty for latest)
```

---

## firmware-status — Get Firmware Status

Retrieves current firmware version, available updates, and update status.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    firmware-status
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## firmware-get — Get Firmware Configuration

Returns firmware configuration details and settings.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    firmware-get
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## firewall-rules-list — List Firewall Filter Rules

Retrieves all firewall filter rules (pass/block rules). Optionally search by description or UUID.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Firewall Filter** | No | Filter rules by description or UUID |
| **Output Format** | No | Format output as JSON (default) or CSV |

### Example

```
Operation:        firewall-rules-list
Host:             192.168.1.1
API Key:          your-api-key
API Secret:       your-api-secret
Verify SSL:       no
Firewall Filter:  (optional, leave empty for all)
Output Format:    json
```

---

## firewall-aliases-list — List Firewall Aliases

Retrieves all configured firewall aliases (IP lists, port lists, etc.).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Output Format** | No | Format output as JSON (default) or CSV |

### Example

```
Operation:       firewall-aliases-list
Host:            192.168.1.1
API Key:         your-api-key
API Secret:      your-api-secret
Verify SSL:      no
Output Format:   json
```

---

## firewall-nat-list — List NAT Rules

Retrieves all NAT rules: destination NAT, source NAT, and 1:1 NAT.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Output Format** | No | Format output as JSON (default) or CSV |

### Example

```
Operation:       firewall-nat-list
Host:            192.168.1.1
API Key:         your-api-key
API Secret:      your-api-secret
Verify SSL:      no
Output Format:   json
```

---

## firewall-stats — Get Firewall Statistics

Returns firewall performance metrics and state table statistics.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    firewall-stats
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## diagnostics-firewall-log — Retrieve Firewall Logs

Fetches firewall log entries. Default: 100 lines (configurable).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |
| **Log Lines** | No | Number of log entries to retrieve (default: 100) |

### Example

```
Operation:    diagnostics-firewall-log
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
Log Lines:    100
```

---

## diagnostics-system-info — Get System Information

Returns system details including hostname, OPNsense version, uptime, and platform info.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    diagnostics-system-info
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## diagnostics-system-resources — Get System Resources

Returns real-time system resource usage: CPU, memory, disk, and swap.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    diagnostics-system-resources
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## diagnostics-interface-stats — Get Network Interface Statistics

Returns per-interface statistics including packets, bytes, errors, and collisions.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    diagnostics-interface-stats
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## system-status — Get System Status

Returns overall system status including reboot pending status and various health indicators.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key |
| **API Secret** | Yes | OPNsense API secret |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Example

```
Operation:    system-status
Host:         192.168.1.1
API Key:      your-api-key
API Secret:   your-api-secret
Verify SSL:   no
```

---

## API Key Setup

1. Log in to OPNsense Web UI
2. Navigate to **System → API → Keys**
3. Click **Add** to create a new API key
4. Give it a descriptive name (e.g. `orchelium-agent`)
5. Copy the generated API key and secret
6. Save both securely

The API key is passed in the HTTP header: `Authorization: Bearer`

---

## API Endpoints Used

All endpoints are verified to work on OPNsense version 26+:

| Category | Operation | Endpoint |
|----------|-----------|----------|
| **Backup** | backup-get | `/api/core/backup/backups` |
| | backup-download | `/api/core/backup/download` |
| **Firmware** | firmware-status | `/api/core/firmware/status` |
| | firmware-get | `/api/core/firmware/get` |
| **Firewall** | firewall-rules-list | `/api/firewall/filter/searchRule` |
| | firewall-aliases-list | `/api/firewall/alias/search_item` |
| | firewall-nat-list | `/api/firewall/d_nat/search_rule` (and others) |
| | firewall-stats | `/api/firewall/filter/searchRule` |
| **Diagnostics** | diagnostics-firewall-log | `/api/diagnostics/firewall/log` |
| | diagnostics-system-info | `/api/diagnostics/system/system_information` |
| | diagnostics-system-resources | `/api/diagnostics/system/system_resources` |
| | diagnostics-interface-stats | `/api/diagnostics/interface/get_interface_statistics` |
| **System** | system-status | `/api/core/system/status` |

---

## Output Formats

**JSON** (default)
- Complete structured data
- Easy to parse programmatically
- Suitable for all operations

**CSV** (firewall rules/aliases/NAT only)
- Tabular format
- Easy to import into spreadsheets
- More human-readable for rule lists

**Raw** (logs only)
- Plain text format
- Minimal processing
- Suitable for log parsing

---

## Security Notes

- **API Keys**: Store API keys securely using Orchelium secrets management
- **SSL Verification**: Set `verify_ssl` to "yes" in production with valid certificates
- **API Permissions**: Create OPNsense API users with minimal required permissions
- **Network**: Ensure API communication is restricted to trusted networks
- **Audit**: Monitor API key usage in OPNsense System → API → Keys

---

## Troubleshooting

**Connection Refused**
- Verify OPNsense API is enabled: **System → Settings → Administration**
- Confirm firewall allows API connections on port 443
- Check network connectivity from agent to OPNsense

**Authentication Failed**
- Regenerate API key/secret and verify they're correct
- Verify API user account hasn't been disabled
- Check API user permissions: **System → API → Keys**

**Empty Results**
- Verify API user has appropriate ACL permissions
- Check if filters are too restrictive
- Inspect OPNsense logs: **System → Logs → API**

**SSL Errors**
- Set `verify_ssl` to "no" for self-signed certificates
- Or upload OPNsense CA certificate to agent
- For production, use proper certificates

---

## Prerequisites

- OPNsense firewall with REST API enabled
- API credentials (key and secret) generated in OPNsense: **System → API → Keys**
- API user must have appropriate permissions for accessed endpoints
- Network connectivity from Orchelium agent to OPNsense host
