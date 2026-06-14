# Docker Plugin

Manage Docker containers and images on the agent host. Supports starting, stopping, executing commands, running one-off containers, pulling images, viewing logs, pruning, and more.

---

## Common Parameters

All operations accept:

| Parameter | Description |
|-----------|-------------|
| **Docker Host** | Override Docker socket, e.g. `tcp://192.168.1.10:2376` |

---

## start — Start a Stopped Container

Start one or more stopped containers.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:     start
Container:     my-database
```

---

## stop — Stop a Running Container

Stop one or more running containers with a configurable grace period.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Stop Timeout (seconds)** | No | Grace period before SIGKILL (default: 10s) |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:     stop
Container:     my-database
Timeout:       30
```

---

## restart — Restart a Container

Restart one or more containers (stop + start).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:    restart
Container:    my-app
```

---

## exec — Run a Command Inside a Container

Execute a command inside a running container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Exec Command** | Yes | Command to run inside the container |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:       exec
Container:       my-database
Exec Command:    /bin/sh -c 'pg_dump mydb > /var/backups/dump.sql'
```

---

## run — Create and Start a Temporary Container

Create and run a one-off container from an image, then automatically remove it after it exits.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Image** | Yes | Docker image reference, e.g. `nginx:latest` |
| **Run Command** | No | Override the image entrypoint/command |
| **Volume Mounts** | No | Space-separated: `host:container` or `host:container:mode` |
| **Environment Variables** | No | Space-separated: `KEY=value KEY2=value2` |
| **Network** | No | Docker network to attach to |
| **Extra docker run Flags** | No | Any additional `docker run` flags |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:       run
Image:           postgres:16-alpine
Run Command:     pg_dump -h db -U postgres mydb
Volumes:         /mnt/backup:/backup
Environment:     PGPASSWORD=secret DB_HOST=db
Network:         myapp_network
Extra Flags:     --rm
```

---

## pull — Pull an Image from a Registry

Pull an image from a Docker registry (Docker Hub, GitHub Container Registry, etc.).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Image** | Yes | Docker image reference, e.g. `ghcr.io/myorg/myapp:latest` |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:    pull
Image:        ghcr.io/myorg/myapp:latest
```

---

## rm — Remove a Stopped Container

Remove one or more stopped containers.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:    rm
Container:    old-container
```

---

## logs — Fetch Container Logs

Fetch recent log output from a container.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Log Lines** | No | Number of recent lines to fetch (default: 100) |
| **Logs Since** | No | Show logs since a time, e.g. `1h` or `2026-05-15T00:00:00` |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:      logs
Container:      my-app
Log Lines:      200
Logs Since:     2h
```

---

## ps — List Containers

List all containers (running and stopped, configurable).

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Show All Containers** | No | Include stopped containers (`yes`/`no`; default: `no`) |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:    ps
Show All:     yes
```

---

## inspect — Show Container Details

Return low-level container information as JSON.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Container Name / ID** | Yes | Container name or ID |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:    inspect
Container:    my-app
```

---

## prune — Remove Stopped Containers and Dangling Images

Remove all stopped containers, dangling images, and unused networks.

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| **Also Prune Volumes** | No | Remove unused volumes too (`yes`/`no`; default: `no`) |
| **Docker Host** | No | Override Docker socket |

### Example

```
Operation:         prune
Also Prune Volumes: no
```

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
