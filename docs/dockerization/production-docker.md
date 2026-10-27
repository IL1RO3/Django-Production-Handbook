# 24. Docker in production

Docker changes where your app runs, not what you are responsible for. This chapter turns the previous chapters' images and Compose files into something you can safely operate on a server.

## Security baseline

- **Do not put secrets in the Dockerfile** (no `ENV SECRET_KEY=...`) and **do not commit a real `.env` file**. A secret baked into a layer travels with the image through every registry and cache.
- **Run containers as a non-root user.** The Dockerfile should end with `USER app`.
- **Pin base images** (`python:3.13-slim`, `postgres:16`) and rebuild on a schedule to pick up security fixes. Floating tags such as `latest` are not a versioning strategy.
- **Do not publish database or cache ports.** Publish only the proxy's `80`/`443`. PostgreSQL and Redis stay on the private Compose network.
- **Persist database and media** in named volumes or external storage.
- **Back up database data outside the Docker host.** A container and its volume live on one machine; a disk failure can take both.
- **Add health checks** so Compose and orchestrators know when a service is actually ready.

## Where secrets come from

Compose resolves `${POSTGRES_PASSWORD}` and similar variables from:

1. the shell environment of whoever runs `docker compose`,
2. a `.env` file in the project directory,
3. `environment:` or `env_file:` in the service definition.

For a server deployment, prefer a dedicated environment file that is outside Git, owned by a deploy user, and mode `600`. Load it explicitly:

```bash
docker compose --env-file /etc/<APP_NAME>/<APP_NAME>.env up -d
```

Keep the secrets in one place and pass them in; never hard-code them in `docker-compose.yml`.

## Registries and image delivery

Building an image on the production server works for one box, but a **registry** is the cleaner flow: build once (locally or in CI), push, then pull the exact tag everywhere.

```bash
docker build -t ghcr.io/<ORG>/<APP_NAME>:0.1.0 .
docker push ghcr.io/<ORG>/<APP_NAME>:0.1.0
```

On the server:

```bash
docker pull ghcr.io/<ORG>/<APP_NAME>:0.1.0
```

A registry gives you versioned, immutable artifacts and a clean rollback story. Use a private registry (GitHub Container Registry, GitLab, Docker Hub private, or a cloud registry) for private code. A public image of a proprietary app is a leak, not a feature.

## Deploying with Compose on one VPS

A minimal production layout on a single server:

```text
/srv/<APP_NAME>/
├── docker-compose.yml      # production Compose file
├── .env                    # secrets, mode 600, not in Git
├── Caddyfile               # proxy config (or use a proxy image)
└── <APP_NAME>.env          # app environment (optional separate file)
```

The deploy step is a tagged pull plus a recreate:

```bash
docker compose pull
docker compose up -d --no-deps web
```

`--no-deps` restarts only the web service, leaving the database running. Compose starts a new container from the new image and stops the old one, which gives you a short restart rather than a full stack teardown. For a zero-downtime deployment you need more than one web replica and a load balancer; see [Scaling](../operations/scaling.md).

### Run migrations before starting the new code

```bash
docker compose run --rm web python manage.py migrate
docker compose run --rm web python manage.py collectstatic --noinput
docker compose up -d --no-deps web
```

Apply migrations with the old code still serving when possible, then start the new image. See [Safe deployments](../operations/deployment-runbooks.md).

## Static files and media

Decide where they live before you go live:

- **Static files** are best collected at build time (`RUN python manage.py collectstatic --noinput`) and served by the proxy or a CDN. If you collect into a shared named volume, do it once and keep the proxy pointed at it.
- **Media files** are user uploads. They must persist outside the container. Use a named volume or, better, object storage (S3-compatible) so media survives server and container replacement.

## Backups

The database runs in a container, but backups are a host-level responsibility:

```bash
docker compose exec -T db pg_dump -U <DB_USER> -d <DB_NAME> --format=custom > backup.dump
```

Schedule this with a host cron job or systemd timer, verify the dump with `pg_restore --list`, and copy it **off the host** to object storage or another server. A backup that only lives on the same disk as the database is not a backup. See [Backups and disaster recovery](../operations/backups-and-disaster-recovery.md).

## Logs

Containers write to stdout/stderr, and `docker compose logs` reads them back. For a long-running server you should also ship logs to a collector or use the Docker logging driver:

```yaml
services:
  web:
    logging:
      driver: json-file
      options:
        max-size: "10m"
        max-file: "5"
```

`max-size`/`max-file` rotate the JSON logs so a chatty app cannot fill the disk. See [Observability](../operations/observability-and-incidents.md) for monitoring and alerting.

## Resource limits

A container can consume all available CPU and memory unless you limit it. For a busy host, set explicit limits:

```yaml
services:
  web:
    deploy:
      resources:
        limits:
          cpus: "1.0"
          memory: 512M
```

These limits matter most when several services share one host or when a memory leak could take down the box. They do not replace fixing the leak.

## Common production mistakes

- shipping a `.env` file or secret inside the image;
- running the container as root;
- publishing PostgreSQL/Redis ports to the public internet;
- using `latest` as the deployed tag with no rollback path;
- keeping the database on a bind mount or, worse, in the container filesystem;
- backing up only to the same host;
- copying a development Compose file (reloaders, mounted code, open ports) into production.

## Production questions to answer before going live

- Where are images built: server, CI, registry?
- How are secrets provided without committing `.env`?
- How does `collectstatic` run and where do static files land?
- Where do media files persist?
- How are database backups created and copied off-host?
- How are containers restarted after reboot?
- How are logs collected and rotated?
- How are image updates tested and rolled back?
- What is the memory/CPU budget per service?

Compose can be clean and practical, but it does not answer those questions for you. Dockerization removes environment surprises; it does not remove operations.
