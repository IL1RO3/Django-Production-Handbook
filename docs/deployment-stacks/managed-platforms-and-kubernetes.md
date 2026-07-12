# 21. PaaS, managed hosting, serverless, and Kubernetes

## Managed PaaS

A PaaS generally accepts code or a container image and provides routing, TLS, logs, environment variables, process execution, and sometimes a managed database.

**Good fit:** solo developers/small teams that want fast deployment and less OS administration.

**Still your responsibility:** Django settings, migrations, data model, secrets, access control, application logs, backup policy, testing, vendor limits, and release/rollback workflow.

## Managed databases

A managed PostgreSQL service shifts patching, replication, and some backup burden to the provider. It does not mean “never export data” or “ignore restore testing.” You still need access controls, connection security, retention awareness, and recovery documentation.

## Serverless

Serverless functions can work for request-driven workloads, but a traditional stateful Django app may need adaptation for cold starts, storage, WebSockets, migrations, scheduled work, and database connections. Choose it for its operational/economic fit, not as a default replacement for a VPS.

## Kubernetes

Kubernetes coordinates containers across machines. Its core concepts include:

| Object | Role |
|---|---|
| Deployment | desired replica count and rollout behavior |
| Pod | running unit containing one/more containers |
| Service | stable internal network endpoint |
| Ingress/Gateway | HTTP/TLS entry routing |
| ConfigMap | non-secret config |
| Secret | sensitive configuration reference |
| PersistentVolume | durable storage abstraction |

**Use Kubernetes when:** you have multiple services, multiple environments, a team able to operate it, clear scaling/availability needs, and a reason to standardize orchestration.

**Do not start there when:** one Django app on one VPS is your reality. Kubernetes can make a simple system difficult to understand, debug, and secure.

## A sensible growth path

```text
single VPS + systemd
→ add backups/monitoring/staging
→ managed database or object storage
→ multiple app instances behind a proxy/load balancer
→ containers/Compose where helpful
→ managed container platform or Kubernetes only when justified
```

The best architecture is the smallest one that reliably meets present requirements and can be evolved without losing data or operational clarity.

## PaaS deployment mental model

A typical PaaS flow looks like this:

```text
git push or container image
  -> platform builds/release artifact
  -> platform starts web process
  -> platform routes HTTPS traffic
  -> app connects to managed database/add-ons
```

The platform may hide Linux users, systemd, Nginx, and certificate files. It does not hide Django production concerns. You still configure `DEBUG=False`, `ALLOWED_HOSTS`, database URLs, static files, migrations, secrets, health checks, logs, and rollback.

## Common PaaS config concepts

| Concept | Meaning |
|---|---|
| build command | installs dependencies and prepares assets |
| start command | runs Gunicorn/Uvicorn or another app server |
| environment variables | deployment-specific config/secrets |
| release phase/job | runs migrations or setup commands during release |
| dyno/instance | running process/container managed by the platform |
| add-on | managed database/cache/email/logging service |
| health check | endpoint the platform uses to decide whether the app is alive |

A PaaS is often the fastest way to get a correct public app, but read its limits: request timeout, filesystem persistence, background workers, cron/scheduler support, database connection caps, and billing behavior.

## Serverless Django concerns

Serverless is not just "Django but cheaper." Watch for:

- cold starts after idle periods;
- read-only or temporary filesystems;
- short execution time limits;
- database connection storms from many function instances;
- difficulty running migrations safely;
- background jobs and scheduled tasks needing separate services;
- WebSocket support depending on provider architecture.

Use serverless when its constraints match the app. Do not force a traditional Django monolith into it without testing the operational model.

## Kubernetes objects in a Django deployment

A simplified Kubernetes Django setup may include:

```text
Ingress/Gateway
  -> Service
  -> Deployment with Django pods
  -> Secret for env vars
  -> ConfigMap for non-secret config
  -> Job for migrations
  -> managed PostgreSQL outside cluster
  -> object storage for media
```

For most teams, PostgreSQL should be managed outside the cluster unless the team has real database operations experience on Kubernetes.

## Kubernetes beginner translation

| Kubernetes term | Rough beginner translation |
|---|---|
| Pod | one running copy of one or more containers |
| Deployment | rule saying how many pod copies should exist and how to update them |
| Service | stable internal address for a set of pods |
| Ingress | public HTTP routing into services |
| ConfigMap | non-secret settings file/key-value store |
| Secret | secret-like key-value store, still requiring careful access control |
| Job | run-to-completion task such as migrations |
| HPA | autoscaler that changes replica count from metrics |

## Kubernetes failure modes beginners underestimate

- migrations running more than once or at the wrong time;
- pods restarting because readiness/liveness probes are wrong;
- app replicas sharing no media storage;
- database connection count exploding as replicas scale;
- secrets existing in too many namespaces or CI logs;
- ingress/proxy headers not matching Django HTTPS settings;
- logs disappearing because no central log collection exists;
- YAML applying successfully while the app is still broken.

Kubernetes is powerful, but it moves complexity from one server into a platform. Use it when you are ready to operate the platform too.
