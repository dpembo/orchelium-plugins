# Systemd Service Plugin

Manage systemd services on the Orchelium agent host. Start, stop, restart,
reload, enable, disable, or query the status of any systemd unit using
`systemctl`.

---

## Requirements

- `systemd` must be the init system on the agent host (most modern Debian,
  Ubuntu, Fedora, Arch, openSUSE, and derivatives).
- The agent process must have sufficient privileges to manage system-wide
  units. For most operations you will need to run the agent as root or use
  `sudo`. User-mode units (`--user`) only require the calling user's session.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `start` | Start the service unit |
| `stop` | Stop the service unit |
| `restart` | Stop then start the service unit |
| `reload` | Ask the service to reload its configuration without restarting |
| `enable` | Enable the unit to start at boot |
| `disable` | Disable the unit from starting at boot |
| `status` | Show the full unit status (same as `systemctl status`) |
| `is-active` | Returns exit code 0 if the unit is active, non-zero otherwise |

---

## Parameters

| Parameter | Required | Default | Description |
|-----------|----------|---------|-------------|
| **Operation** | Yes | `status` | The systemctl operation to run |
| **Service Name** | Yes | — | Unit name, e.g. `nginx` or `nginx.service` |
| **User Mode** | No | `false` | Use `--user` flag for per-user units |
| **Non-blocking** | No | `false` | Return immediately without waiting for job completion |

---

## Usage Examples

```yaml
# Check whether nginx is running
operation: status
service: nginx

# Restart the docker daemon
operation: restart
service: docker

# Enable a service at boot
operation: enable
service: postgresql

# Stop a service before a backup
operation: stop
service: mysql

# Manage a user-level service
operation: start
service: pulseaudio
user_mode: true
```

---

## Notes

- The `.service` suffix is optional — `nginx` and `nginx.service` are
  equivalent.
- `enable` and `disable` persist across reboots but do not immediately
  start or stop the unit. Combine with a `start`/`stop` node if needed.
- On success, the plugin emits a JSON summary with `success`, `operation`,
  `service`, and (for `status`/`is-active`) `activeState`.
