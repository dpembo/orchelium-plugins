# OPNsense Firewall Plugin

Query and manage OPNsense firewall configurations, backups, and diagnostics using the OPNsense REST API.

This plugin provides comprehensive access to OPNsense system management including:
- **Backup & Restore** — Download full configuration backups
- **Firmware Management** — Check firmware status and configuration
- **Firewall Rules** — List and query filter rules, aliases, and NAT rules
- **Diagnostics** — Access firewall logs, system info, and interface statistics
- **System Status** — Get real-time system health and status information

---

## Prerequisites

- OPNsense firewall with REST API enabled
- API credentials (key and secret) generated in OPNsense: **System → API → Keys**
- API user must have appropriate permissions for accessed endpoints
- Network connectivity from Orchelium agent to OPNsense host

---

## API Endpoints Used

All endpoints are verified to work on current OPNsense version (2026):

| Category | Endpoint | Description |
|----------|----------|-------------|
| **Backup** | `/api/core/backup/download` | Download full config XML |
| | `/api/core/backup/backups` | List available backups |
| **Firmware** | `/api/core/firmware/status` | Get firmware version & status |
| | `/api/core/firmware/get` | Get firmware configuration |
| **Firewall** | `/api/firewall/filter/searchRule` | List firewall filter rules |
| | `/api/firewall/alias/search_item` | List firewall aliases |
| | `/api/firewall/d_nat/search_rule` | List destination NAT rules |
| | `/api/firewall/source_nat/search_rule` | List source NAT rules |
| | `/api/firewall/one_to_one/search_rule` | List 1:1 NAT rules |
| | `/api/firewall/filter/searchRule` | Firewall statistics |
| **Diagnostics** | `/api/diagnostics/firewall/log` | Firewall logs |
| | `/api/diagnostics/system/system_information` | System information |
| | `/api/diagnostics/system/system_resources` | CPU, memory, disk usage |
| | `/api/diagnostics/interface/get_interface_statistics` | Network interface stats |
| **System** | `/api/core/system/status` | System status & reboot pending |

---

## Parameters

### Connection Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Host** | Yes | IP address or hostname of OPNsense firewall |
| **API Key** | Yes | OPNsense API key (from System → API → Keys) |
| **API Secret** | Yes | OPNsense API secret (paired with API key) |
| **Verify SSL** | No | Whether to verify SSL certificate (default: no) |

### Operation-Specific Parameters

| Parameter | Operations | Description |
|-----------|-----------|-------------|
| **Backup ID** | `backup-download` | Specific backup to download (optional; uses latest if empty) |
| **Firewall Filter** | `firewall-rules-list` | Filter rules by description or UUID |
| **Log Lines** | `diagnostics-firewall-log` | Number of log entries to retrieve (default: 100) |
| **Output Format** | All | Format output as JSON, CSV, or raw (default: JSON) |

---

## Operations

### Backup Operations

#### `backup-get` — List Available Backups
Retrieves list of available configuration backups with metadata.

**Response:**
```json
{
  "rows": [
    {
      "name": "backup-2026-06-12-120000",
      "mtime": 1718181600
    }
  ]
}
```

#### `backup-download` — Download Backup
Downloads a full OPNsense configuration backup as XML.

**Optional:** Specify `backup_id` to download a specific backup. If not specified, downloads the most recent.

**Response:**
```json
{
  "success": true,
  "filename": "opnsense-backup-20260612-120530.xml",
  "size": 256000
}
```

**File Output:** XML configuration file saved to agent filesystem.

---

### Firmware Operations

#### `firmware-status` — Get Firmware Status
Retrieves current firmware version, available updates, and update status.

**Response:**
```json
{
  "core": {
    "version": "26.1.1",
    "ready": true,
    "reboot_required": false
  },
  "plugins": [...]
}
```

#### `firmware-get` — Get Firmware Configuration
Returns firmware configuration details.

**Response:**
```json
{
  "firmware": {
    "allow_dev_url": "0",
    "allow_prerelease": "0",
    "auto_check": "1"
  }
}
```

---

### Firewall Operations

#### `firewall-rules-list` — List Firewall Rules
Retrieves all firewall filter rules (pass/block rules).

**Optional:** Use `firewall_filter` parameter to search by description or UUID.

**Response (JSON):**
```json
{
  "total": 25,
  "rows": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440000",
      "description": "Allow SSH",
      "action": "pass",
      "protocol": "TCP",
      "source_net": "any",
      "destination_net": "any",
      "interface": "wan",
      "enabled": "1"
    }
  ]
}
```

**Response (CSV):**
```
UUID,Description,Action,Protocol,Source,Destination,Interface,Enabled
550e8400-e29b-41d4-a716-446655440000,Allow SSH,pass,TCP,any,any,wan,1
```

#### `firewall-aliases-list` — List Firewall Aliases
Retrieves all configured firewall aliases (IP lists, port lists, etc.).

**Response (JSON):**
```json
{
  "rows": [
    {
      "uuid": "550e8400-e29b-41d4-a716-446655440001",
      "name": "RFC1918",
      "type": "network",
      "description": "Private Networks",
      "content": "10.0.0.0/8 172.16.0.0/12 192.168.0.0/16"
    }
  ]
}
```

#### `firewall-nat-list` — List NAT Rules
Retrieves all NAT rules across all types: destination NAT, source NAT, and 1:1 NAT.

**Response (JSON):**
```json
{
  "destination_nat": [...],
  "source_nat": [...],
  "one_to_one_nat": [...],
  "total": 12
}
```

#### `firewall-stats` — Get Firewall Statistics
Returns firewall performance metrics and state table statistics.

**Response:**
```json
{
  "packets_processed": 1524000,
  "packets_blocked": 3500,
  "states_active": 245,
  "state_memory": "18 MB"
}
```

---

### Diagnostics Operations

#### `diagnostics-firewall-log` — Retrieve Firewall Logs
Fetches firewall log entries (default: 100 lines, configurable via `diagnostics_lines`).

**Response:**
```json
{
  "rows": [
    {
      "timestamp": "2026-06-12 12:05:30",
      "action": "block",
      "protocol": "TCP",
      "source_ip": "203.0.113.45",
      "destination_ip": "192.168.1.1",
      "port": "443",
      "rule_number": "1001"
    }
  ]
}
```

#### `diagnostics-system-info` — Get System Information
Returns system details including hostname, OPNsense version, uptime, and platform info.

**Response (JSON):**
```json
{
  "hostname": "firewall.example.com",
  "version": "26.1.1",
  "platform": "QEMU",
  "uptime": "35 days, 14:23",
  "last_reboot": "2026-05-08 12:30:00"
}
```

#### `diagnostics-system-resources` — Get System Resources
Returns real-time system resource usage: CPU, memory, disk, and swap.

**Response:**
```json
{
  "cpu_usage": 18,
  "memory_used": "2048 MB",
  "memory_total": "4096 MB",
  "memory_percent": 50,
  "disk_used": "15 GB",
  "disk_total": "50 GB",
  "disk_percent": 30,
  "swap_used": "0 MB",
  "swap_total": "2048 MB"
}
```

#### `diagnostics-interface-stats` — Get Network Interface Statistics
Returns per-interface statistics including packets, bytes, errors, and collisions.

**Response:**
```json
{
  "rows": [
    {
      "interface": "wan",
      "description": "WAN",
      "packets_in": 1524000,
      "bytes_in": 2048000000,
      "packets_out": 856000,
      "bytes_out": 1024000000,
      "errors": 0,
      "dropped": 5
    }
  ]
}
```

---

### System Operations

#### `system-status` — Get System Status
Returns overall system status including reboot pending status and various health indicators.

**Response:**
```json
{
  "hostname": "firewall",
  "domain": "example.com",
  "timezone": "UTC",
  "uptime": 3067200,
  "uptime_readable": "35 days 14:00:00",
  "last_reboot": "2026-05-08 12:30:00",
  "pending_reboot": false,
  "pkgs_updates_count": 0
}
```

---

## Examples

### Example 1: Check Firewall Status
```bash
orchelium run opnsense \
  --host 192.168.1.1 \
  --api_key "your-api-key" \
  --api_secret "your-api-secret" \
  --operation system-status
```

### Example 2: Download Latest Backup
```bash
orchelium run opnsense \
  --host 192.168.1.1 \
  --api_key "your-api-key" \
  --api_secret "your-api-secret" \
  --operation backup-download
```

### Example 3: List Firewall Rules (CSV Format)
```bash
orchelium run opnsense \
  --host 192.168.1.1 \
  --api_key "your-api-key" \
  --api_secret "your-api-secret" \
  --operation firewall-rules-list \
  --output_format csv
```

### Example 4: Get System Resources
```bash
orchelium run opnsense \
  --host 192.168.1.1 \
  --api_key "your-api-key" \
  --api_secret "your-api-secret" \
  --operation diagnostics-system-resources
```

### Example 5: Get Last 50 Firewall Logs
```bash
orchelium run opnsense \
  --host 192.168.1.1 \
  --api_key "your-api-key" \
  --api_secret "your-api-secret" \
  --operation diagnostics-firewall-log \
  --diagnostics_lines 50
```

---

## Security Notes

- **API Keys**: Store API keys securely using Orchelium secrets management
- **SSL Verification**: Set `verify_ssl` to "yes" in production with valid certificates
- **API Permissions**: Create OPNsense API users with minimal required permissions
- **Network**: Ensure API communication is restricted to trusted networks
- **Audit**: Monitor API key usage in OPNsense System → API → Keys

---

## Troubleshooting

### Connection Refused
- Verify OPNsense API is enabled: **System → Settings → Administration**
- Confirm firewall allows API connections on port 443
- Check network connectivity from agent to OPNsense

### Authentication Failed
- Regenerate API key/secret and verify they're correct
- Verify API user account hasn't been disabled
- Check API user permissions: **System → API → Keys**

### Empty Results
- Verify API user has appropriate ACL permissions
- Check if filters are too restrictive
- Inspect OPNsense logs: **System → Logs → API**

### SSL Errors
- Set `verify_ssl` to "no" for self-signed certificates
- Or upload OPNsense CA certificate to agent
- For production, use proper certificates

---

## Version History

**1.0.0** (2026-06-12)
- Initial release
- Support for backup, firmware, firewall rules, aliases, NAT rules
- Diagnostics: firewall logs, system info, resources, interface stats
- JSON and CSV output formats
- API verified against OPNsense 26.1.1
