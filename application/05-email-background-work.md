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
