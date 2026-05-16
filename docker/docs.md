# Docker Plugin

Manage Docker containers and images on the agent host. Supports starting, stopping, executing commands, running one-off containers, pulling images, viewing logs, pruning, and more.

---

## Operations

| Operation | Description |
|-----------|-------------|
| `start` | Start a stopped container |
| `stop` | Stop a running container |
| `restart` | Restart a container |
| `exec` | Run a command inside a running container |
| `run` | Create and start a temporary container from an image |
| `pull` | Pull an image from a registry |
| `rm` | Remove a stopped container |
| `logs` | Fetch recent container logs |
| `ps` | List containers |
| `inspect` | Show detailed container information |
| `prune` | Remove all stopped containers and dangling images |

---

## Parameters

| Parameter | Required | Operations | Description |
|-----------|----------|------------|-------------|
| **Operation** | Yes | — | Operation to perform |
| **Container Name / ID** | start, stop, restart, exec, rm, logs, inspect | Container name or ID |
| **Image** | run, pull | Docker image reference, e.g. `nginx:latest` |
| **Exec Command** | exec | Command to run inside the container |
| **Run Command** | No | run | Override the image entrypoint/command |
| **Volume Mounts** | No | run | Space-separated: `host:container` or `host:container:mode` |
| **Environment Variables** | No | run | Space-separated: `KEY=value KEY2=value2` |
| **Network** | No | run | Docker network to attach to |
| **Extra docker run Flags** | No | run | Any additional `docker run` flags |
| **Stop Timeout (seconds)** | No | stop | Grace period before SIGKILL (default: 10s) |
| **Log Lines** | No | logs | Number of recent lines to fetch (default: 100) |
| **Logs Since** | No | logs | Show logs since a time, e.g. `1h` or `2026-05-15T00:00:00` |
| **Show All Containers** | No | ps | Include stopped containers (`yes`/`no`) |
| **Also Prune Volumes** | No | prune | Remove unused volumes too (`yes`/`no`) |
| **Docker Host** | No | All | Override Docker socket, e.g. `tcp://192.168.1.10:2376` |

---

## Usage Examples

### Stop a container, run a backup, then restart

Chain three plugin nodes in your orchestration:

```
Node 1: stop
  Container: my-database

Node 2: exec  (or run)
  Container: my-database
  Exec Command: /bin/sh -c 'pg_dump mydb > /var/backups/dump.sql'

Node 3: start
  Container: my-database
```

### Run a one-off backup container

```
Operation:       run
Image:           postgres:16-alpine
Run Command:     pg_dump -h db -U postgres mydb
Volumes:         /mnt/backup:/backup
Environment:     PGPASSWORD=secret DB_HOST=db
Network:         myapp_network
Extra Flags:     --rm
```

### Pull the latest image

```
Operation:    pull
Image:        ghcr.io/myorg/myapp:latest
```

### View recent container logs

```
Operation:      logs
Container:      my-app
Log Lines:      200
Logs Since:     2h
```

### Prune all stopped containers

```
Operation:         prune
Also Prune Volumes: no
```

### List all containers (including stopped)

```
Operation:        ps
Show All:         yes
```

### Connect to a remote Docker daemon

```
Operation:       ps
Docker Host:     tcp://192.168.1.50:2376
Show All:        yes
```

---

## Volume Mount Format

Volume mounts for `run` are space-separated pairs:

```
/mnt/backup:/backup  /etc/config:/config:ro  /var/data:/data
```

---

## Tips

- Use `exec` for commands against already-running containers; use `run` to spin up a throwaway container.
- Add `--rm` to **Extra docker run Flags** for `run` so the container is removed automatically after it exits.
- The `prune` operation only removes *stopped* containers and *dangling* images — running containers are not affected.
- Set **Docker Host** to control a remote Docker daemon without SSH; ensure the daemon is secured appropriately.
- For database backups, prefer stopping the container (or at least flushing writes via `exec`) before copying data files.

---

## Requirements

- Docker Engine installed on the agent host
- The agent must have permission to access the Docker socket (`/var/run/docker.sock`) or the configured remote host
