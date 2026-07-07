# 27. Scaling without premature complexity

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
