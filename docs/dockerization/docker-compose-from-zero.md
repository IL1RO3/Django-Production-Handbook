# 23. Docker Compose from zero

Docker Compose describes a multi-service application in a single YAML file. Instead of starting the web app, database, cache, worker, and proxy with separate `docker run` commands, you declare them once and manage them together.

## Compose, not "docker-compose"

Compose v2 ships as a Docker plugin invoked with a space: `docker compose`. The old `docker-compose` (hyphenated) binary is deprecated. The rest of this chapter uses `docker compose`.

## Minimal conceptual topology

```text
Caddy/Nginx container → web (Gunicorn/Uvicorn) container → PostgreSQL container
                                        ↘ Redis/worker container (optional)
```

## A complete `docker-compose.yml`

```yaml
services:
  web:
    build: .
    command: gunicorn <PROJECT_PACKAGE>.wsgi:application --bind 0.0.0.0:8000 --workers 3
    env_file: .env
    depends_on:
      db:
        condition: service_healthy
    expose:
      - "8000"

  db:
    image: postgres:16
    environment:
      POSTGRES_DB: <DB_NAME>
      POSTGRES_USER: <DB_USER>
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U <DB_USER> -d <DB_NAME>"]
      interval: 10s
      timeout: 5s
      retries: 5

  proxy:
    image: caddy:2
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile:ro
      - caddy_data:/data
      - static_data:/srv/static:ro
    depends_on:
      - web

volumes:
  postgres_data:
  caddy_data:
  static_data:
```

This is a conceptual starting point, not a copy-paste production answer. You still must decide how `collectstatic` populates the static volume, how media persists, how backups reach the database, where production secrets come from, and how image versions are pinned. The walkthrough below explains each block.

## Walk through the file

### `services:`

`services` is the top-level map of containers Compose should run. Each service gets a name, a network identity, and its own configuration.

### `web` — the Django app

```yaml
web:
  build: .
```

`build: .` tells Compose to build an image from the `Dockerfile` in the current directory. If you already push a pre-built image to a registry, use `image: <registry>/<APP_NAME>:0.1.0` instead of `build:`.

```yaml
  command: gunicorn <PROJECT_PACKAGE>.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

This overrides the Dockerfile's `CMD` with the process the web container runs. Inside a container, binding to `0.0.0.0` means "listen on all interfaces inside the container"; it does not publish the port publicly.

```yaml
  env_file: .env
```

Compose loads environment variables from `.env` into the container. Never commit a real production `.env` file.

```yaml
  depends_on:
    db:
      condition: service_healthy
```

Compose waits until the database health check passes before starting the web service. It helps startup order, but the application should still handle temporary database failures gracefully.

```yaml
  expose:
    - "8000"
```

`expose` documents and opens the port to other Compose services on the internal network. It is **not** the same as `ports`, which publishes a port to the host.

### `db` — PostgreSQL

```yaml
db:
  image: postgres:16
```

The `db` service runs the official PostgreSQL image. Pin a major version deliberately; changing database major versions is an upgrade project, not a casual edit.

```yaml
  environment:
    POSTGRES_DB: <DB_NAME>
    POSTGRES_USER: <DB_USER>
    POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
```

The `postgres` image uses these variables to initialize the database on first run. `${POSTGRES_PASSWORD}` is substituted by Compose from your environment or `.env` file; it is not passed to the web container.

```yaml
  volumes:
    - postgres_data:/var/lib/postgresql/data
```

This stores PostgreSQL data in a named volume. Without persistent storage, deleting or recreating the container can destroy the database.

```yaml
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U <DB_USER> -d <DB_NAME>"]
    interval: 10s
    timeout: 5s
    retries: 5
```

This tells Compose how to ask PostgreSQL whether it is ready to accept connections. A service is "healthy" only when the check succeeds, which `depends_on: condition: service_healthy` waits for.

### `proxy` — the public front door

```yaml
proxy:
  image: caddy:2
  ports:
    - "80:80"
    - "443:443"
```

The proxy publishes HTTP and HTTPS from the host to the container. Do not publish PostgreSQL or Redis this way for a normal public deployment.

```yaml
  volumes:
    - ./Caddyfile:/etc/caddy/Caddyfile:ro
    - caddy_data:/data
    - static_data:/srv/static:ro
```

This mounts the proxy configuration and persistent data. The `static_data` volume is where collected static files land so the proxy can serve them directly, keeping Django workers free for dynamic requests. The example omits the web side of that wiring: you must decide where `collectstatic` runs and how it populates the volume.

## Volumes: named versus bind mount

| Kind | Syntax | Use |
|---|---|---|
| named volume | `postgres_data:/var/lib/postgresql/data` | durable data Docker manages, such as the database |
| bind mount | `./Caddyfile:/etc/caddy/Caddyfile:ro` | a host file or directory, such as a config file |

Named volumes are the right choice for the database and anything that must survive container replacement. Bind mounts are convenient for config files you edit on the host. The `:ro` suffix makes a bind mount read-only.

## Networking mental model

Compose creates a private network for the services. Each service is reachable by its service name:

```text
web container -> db:5432
proxy container -> web:8000
```

Inside Compose, `db` is a DNS name, not a public address. From your laptop or the public internet, `db` is not automatically reachable. Public access happens only through published `ports`.

## Compose commands

```bash
docker compose up --build      # build images and start services in the foreground
docker compose up -d --build   # the same, detached
docker compose ps              # list services and their status
docker compose logs -f web     # follow the web service logs
docker compose down            # stop and remove containers (keeps volumes)
docker compose down -v         # also remove named volumes (deletes database data)
docker compose build           # build (or rebuild) images only
docker compose restart web     # restart one service
```

Run management commands as one-off containers:

```bash
docker compose run --rm web python manage.py migrate
docker compose run --rm web python manage.py collectstatic --noinput
docker compose run --rm web python manage.py createsuperuser
```

`docker compose run` starts a fresh container for the command; `docker compose exec web <cmd>` runs a command in an already-running service container.

## Restart policy

Add a restart policy so services come back after a reboot or crash:

```yaml
services:
  web:
    restart: unless-stopped
  db:
    restart: unless-stopped
```

`unless-stopped` restarts a container unless you stopped it manually. Combine this with Docker's own startup so the stack recovers after a server reboot.

## Development Compose versus production Compose

Development Compose often mounts source code into the container, enables reloaders, uses simple passwords, and exposes convenience ports. Production Compose should use built images, private networks, real secret handling, pinned versions, backups, logs, and controlled public ports.

Do not copy a local development Compose file to production without reviewing every mount, port, environment variable, and command.

## Image, container, volume: do not mix them up

| Thing | Meaning |
|---|---|
| image | built package/template for a container |
| container | running instance of an image |
| volume | persistent storage managed outside the container filesystem |
| bind mount | host path mounted into a container |
| network | private communication space between containers |

Deleting a container should not delete PostgreSQL data if the data lives in a named volume. Deleting the volume can delete the database.

## Next

Compose makes the topology explicit but does not make it production-safe. [Docker in production](production-docker.md) covers secrets, image pinning, registries, backups, logs, and deployment.
