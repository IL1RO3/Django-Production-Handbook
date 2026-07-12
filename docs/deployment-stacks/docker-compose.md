# 20. Docker Compose

Docker packages processes and dependencies into images/containers. Docker Compose describes a multi-service application in YAML.

## What it solves

- reproducible dependency versions,
- consistent local/CI/server service topology,
- explicit network and volume configuration,
- easier separation between web, worker, database, cache, and proxy services.

## What it does not solve

Containers do not automatically give you secure secrets, TLS, backups, monitoring, database durability, firewall policy, or a good deployment strategy. They make these concerns more explicit; they do not erase them.

## Minimal conceptual Compose topology

```text
Caddy/Nginx container → web (Gunicorn/Uvicorn) container → PostgreSQL container
                                        ↘ Redis/worker container (optional)
```

## Example `docker-compose.yml`

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

This is a conceptual starting point, not a copy-paste production answer. You must decide how `collectstatic` populates the static volume, how media persists, how backups access the database, where production secrets come from, and how image versions are pinned.

## Docker security baseline

- Do not put secrets in Dockerfile `ENV` instructions or commit real `.env` files.
- Run containers as non-root where practical.
- Pin base images and rebuild for security updates.
- Do not publish database/cache ports unless intentionally private/restricted.
- Persist database and media with named volumes or external storage.
- Back up database data outside the Docker host.

## When Compose is worth it

Use it when repeatability and multi-service clarity help your team. Do not force Docker into a one-process hobby project purely for fashion; a well-managed systemd deployment can be simpler and safer for that case.

## Walk through the Compose file

```yaml
services:
```

`services` is the top-level map of containers Compose should run. Each service gets a name, network identity, and configuration.

```yaml
web:
  build: .
```

The `web` service is your Django app container. `build: .` tells Docker to build an image from the Dockerfile in the current directory.

```yaml
command: gunicorn <PROJECT_PACKAGE>.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

This is the process the web container runs. Inside a container, binding to `0.0.0.0` means "listen on all interfaces inside the container." It does not automatically publish the port to the public internet.

```yaml
env_file: .env
```

Compose loads environment variables from `.env`. Do not commit a real production `.env` file.

```yaml
depends_on:
  db:
    condition: service_healthy
```

This asks Compose to wait until the database health check passes before starting the web service. It helps startup order, but the application should still handle temporary database failures gracefully.

```yaml
expose:
  - "8000"
```

`expose` documents and opens the port to other Compose services on the internal network. It is not the same as `ports`, which publishes a port to the host.

```yaml
volumes:
  - postgres_data:/var/lib/postgresql/data
```

This stores PostgreSQL data in a named volume. Without persistent storage, deleting/recreating the database container can destroy data.

```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U <DB_USER> -d <DB_NAME>"]
```

This tells Compose how to ask PostgreSQL whether it is ready to accept connections.

```yaml
ports:
  - "80:80"
  - "443:443"
```

The proxy publishes HTTP and HTTPS from the host to the container. Do not publish PostgreSQL or Redis this way for a normal public deployment.

## Development Compose versus production Compose

Development Compose often mounts source code into the container, enables reloaders, uses simple passwords, and exposes convenience ports. Production Compose should use built images, private networks, real secret handling, pinned versions, backups, logs, and controlled public ports.

Do not copy a local development Compose file to production without reviewing every mount, port, environment variable, and command.

## Compose networking mental model

Compose creates a private network for services. Services can reach each other by service name:

```text
web container -> db:5432
proxy container -> web:8000
```

Inside Compose, `db` is a DNS name. From your laptop or the public internet, `db` is not automatically reachable. Public access happens only through published `ports`.

## Image, container, volume: do not mix them up

| Thing | Meaning |
|---|---|
| image | built package/template for a container |
| container | running instance of an image |
| volume | persistent storage managed outside the container filesystem |
| bind mount | host path mounted into a container |
| network | private communication space between containers |

Deleting a container should not delete PostgreSQL data if the data lives in a named volume. Deleting the volume can delete the database.

## Production questions before choosing Compose

Before using Compose on a server, answer:

- Where are images built: server, CI, registry?
- How are secrets provided without committing `.env`?
- How does `collectstatic` run and where do static files land?
- Where do media files persist?
- How are database backups created and copied off-host?
- How are containers restarted after reboot?
- How are logs collected and rotated?
- How are image updates tested and rolled back?

Compose can be clean and practical, but it does not answer those questions for you.
