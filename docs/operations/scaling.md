# 30. Scaling without premature complexity

Scaling is not only adding servers. First identify the bottleneck.

| Symptom | Possible response |
|---|---|
| Slow queries | indexes, query profiling, pagination, DB tuning |
| CPU-bound app work | optimize code, worker tuning, move background work |
| External API latency | timeouts, retries, background jobs, caching |
| Static bandwidth | CDN/object storage/cache headers |
| Long-running tasks | Celery/RQ/Huey + worker queue |
| Many concurrent WebSockets | ASGI design, connection capacity, Redis/channel layer |
| Single-server failure risk | backups, replica/managed DB, load balancer, multi-instance app |

## Add background workers when work should not block a web request

Email sending, report generation, image processing, and slow external calls are candidates. A queue stack commonly includes:

```text
Django web request → broker (Redis/RabbitMQ) → worker process → result/storage
```

That adds a new service, credentials, monitoring, and failure behavior. Add it when it solves a demonstrated problem.

## Cache carefully

Caching can reduce database work and improve latency. It can also make invalidation, authorization, and stale data harder. Start with clear targets: expensive public list page, repeated computed result, static assets through CDN.

## Horizontal app scaling

Once the app is stateless at the process layer—sessions/cache/uploads handled appropriately—you can run multiple app instances behind a load balancer. Database writes and migration coordination become more important. Do not scale code while neglecting database capacity and backups.

## The evolution rule

Add a component only when you can answer:

1. Which concrete bottleneck does it solve?
2. What new operational responsibility does it create?
3. How will it be monitored, backed up, upgraded, and recovered?

## Common growth stages

A simple beginning is often the most reliable architecture:

```text
One VPS
  -> reverse proxy
  -> Gunicorn/Uvicorn
  -> Django
  -> PostgreSQL
```

A medium architecture separates public web capacity from the data layer:

```text
Load balancer
  -> Django instance A
  -> Django instance B
  -> shared PostgreSQL
  -> shared Redis/cache/broker
  -> shared media/object storage
```

A larger architecture may use managed databases, object storage, CDN, container orchestration, private networks, read replicas, and specialized worker pools. Kubernetes belongs here only when orchestration solves more problems than it creates.

## Make the app stateless before adding app servers

Multiple app servers require shared state:

| State | Single-server shortcut | Multi-server answer |
|---|---|---|
| sessions | local memory | database/cache/signed-cookie sessions |
| media files | local disk | object storage or shared volume |
| cache | local memory | Redis/Memcached/shared cache |
| background jobs | local process | shared broker and worker fleet |
| migrations | manual on server | one coordinated deployment step |

If this work is skipped, a load balancer can make bugs intermittent: uploads appear on one server, sessions disappear on another, and workers fight over duplicated jobs.

## Database scaling comes first for many Django apps

Most Django bottlenecks eventually touch the database. Before adding app instances, check indexes, query counts, pagination, transaction length, connection count, and backup/restore capacity. A single poorly shaped query can overload a large database; a small index can outperform a new server.

## Zero-downtime deployment concepts

Zero downtime means users can continue making successful requests while code changes. It usually requires:

- backwards-compatible migrations;
- health checks;
- draining old workers before killing them;
- a load balancer or process manager that only routes to healthy instances;
- rollback that matches the database state.

Blue/green deployment runs two environments and switches traffic. Rolling deployment replaces instances gradually. Both need compatible code and data. They are deployment disciplines, not magic buttons.

## When to choose managed services

Managed databases, Redis, object storage, CDN, and email providers are often cheaper than operating those systems poorly. The trade-off is vendor limits, network design, access policy, billing, and migration planning. Document every managed dependency the same way you document a VPS.
