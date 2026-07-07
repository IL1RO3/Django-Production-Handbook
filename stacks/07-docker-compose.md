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
