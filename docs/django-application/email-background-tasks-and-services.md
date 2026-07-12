# 9. Email, background work, cache, and external services

A Django deployment is more than HTTP requests. Many applications send email, call third-party APIs, generate files, process images, or calculate reports.

## Email delivery choices

| Method | Advantages | Trade-offs |
|---|---|---|
| SMTP provider | familiar Django configuration | credentials, provider port/rate limits, deliverability setup |
| Transactional email API | explicit HTTP API, often strong delivery tooling | vendor SDK/API key dependency |
| Cloud email service | good scale/integration in cloud environments | provider-specific IAM/domain configuration |
| Development console backend | safe local inspection | does not deliver real email |

Never hard-code SMTP passwords/API tokens in `settings.py`. Use environment variables. In production, set `DEFAULT_FROM_EMAIL`, configure domain authentication (SPF/DKIM/DMARC) according to the provider, and send a real test email before launch.

## Do not make slow work block an HTTP request

A web request should finish promptly. For expensive or unreliable work, use a queue/worker model:

```text
Django request
  → records intent / queues task
  → returns response
  → worker performs email/report/image/API work
```

Common tools:

| Tool | Typical fit |
|---|---|
| Celery | mature distributed task queue; Redis/RabbitMQ broker |
| RQ | simpler Redis-backed job queue |
| Huey | lightweight queue/scheduler option |
| Django-Q / alternatives | project-dependent workflow choices |

Every queue adds operational responsibilities: broker access, worker service, retries, idempotency, observability, and graceful failure. Add one when work genuinely should not occur inside the request lifecycle.

## Caching

Cache repeated expensive work only after measuring a real bottleneck. Common patterns:

- CDN/browser cache for static assets;
- per-view cache for public pages;
- Redis cache for expensive computed results;
- database indexes/pagination before adding cache layers.

Caching is a correctness feature as much as a performance feature: decide when cache entries expire and who is allowed to see them. Never cache authenticated/private responses accidentally.

## External APIs

- Set explicit timeouts; default infinite waits can exhaust workers.
- Handle failure and retry deliberately.
- Keep provider tokens in protected environment variables.
- Use background tasks for slow/retryable integration work.
- Record which external dependency failed in logs without logging secrets.

## Celery and Redis production shape

A common Django queue architecture is:

```text
Django web process
  -> Redis or RabbitMQ broker
  -> Celery worker
  -> database/object storage/email/API
  -> Celery beat for scheduled tasks when needed
```

Run workers as separate systemd services or separate containers. Do not hide workers inside the web process. They need independent restart policy, logs, deployment steps, and health checks.

Production rules for tasks:

- make tasks idempotent where practical;
- set time limits for jobs that can hang;
- use retries with backoff for transient failures;
- store enough task context to debug without storing secrets;
- monitor queue length and worker failures;
- decide what happens when the broker is down.

## Sessions and storage backends

If you run more than one web process or server, state must not live only in process memory. Use database, cache, signed-cookie, or another deliberate session backend. For uploads, prefer a durable media strategy: local disk for a single VPS with backups, or S3-compatible object storage when multiple servers or CDN delivery are required.

Object storage changes behavior: permissions, signed URLs, lifecycle rules, cache headers, backup expectations, and local development settings all need documentation.

## Scheduled tasks

Scheduled jobs can run through cron, systemd timers, Celery beat, Huey, provider schedulers, or CI/manual workflows. Choose one owner per job. Duplicate schedulers can send duplicate emails, charge customers twice, or corrupt generated reports.

Document each scheduled task with:

- command/task name;
- schedule and timezone;
- expected duration;
- retry behavior;
- success/failure alert;
- whether it is safe to run twice.
