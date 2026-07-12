# 3. Choose your stack deliberately

There is no universal “best stack.” There is a best stack for your requirements, team experience, hosting environment, and maintenance budget.

## Decision matrix

| Situation | Recommended starting point | Why |
|---|---|---|
| Conventional Django site/API on one VPS | Nginx + Gunicorn + PostgreSQL | common, clear responsibilities, extensive ecosystem |
| Your organization already uses Apache | Apache + Gunicorn + PostgreSQL | integrates cleanly with existing vhosts/logging/modules |
| You want the simplest TLS experience | Caddy + Gunicorn + PostgreSQL | automatic certificate provisioning/renewal by default |
| You must use Apache only | Apache + mod_wsgi + PostgreSQL | fewer moving processes, mature Apache integration |
| You need WebSockets/async consumers | Nginx/Caddy + Uvicorn/Daphne/Hypercorn + PostgreSQL | ASGI supports long-lived async connections |
| You want repeatable local/prod environments | Docker Compose | explicit services and dependencies |
| You do not want OS administration | managed PaaS + managed database | provider owns more infrastructure work |
| Multiple services/team/complex scaling | container platform/Kubernetes later | operational automation at higher complexity |

## The main families

### Nginx + Gunicorn

**Nginx** is a high-performance web server and reverse proxy. **Gunicorn** runs your WSGI Django workers. Nginx handles public HTTP/HTTPS and static files; Gunicorn stays private.

**Advantages:** widely documented, excellent proxy/static behavior, simple division of roles, straightforward scale-out.

**Trade-offs:** two services to configure and observe; certificates are typically handled with Certbot or another ACME client.

### Apache + Gunicorn

Apache does the same public-front-door job while Gunicorn runs Django. Choose it when Apache is already your standard or you need Apache-specific modules/operations.

**Advantages:** mature vhost model, familiar for existing Apache administrators, strong logging/module ecosystem.

**Trade-offs:** often more verbose than Nginx; do not use Apache and Nginx for the same single-app purpose unless you have a clear architecture reason.

### Apache + mod_wsgi

`mod_wsgi` embeds/hosts WSGI applications through Apache. It can run Django in daemon mode.

**Advantages:** one main HTTP server family; long-standing Django integration; no separate Gunicorn process.

**Trade-offs:** Python interpreter/virtualenv compatibility requires care; deployment and isolation can be less intuitive for beginners. Prefer daemon mode, not embedded mode.

### Caddy + Gunicorn

Caddy is a web server and reverse proxy with automatic HTTPS behavior.

**Advantages:** very compact configuration; certificate provisioning and renewal are designed into the product; good default ergonomics.

**Trade-offs:** fewer examples than Nginx/Apache in some enterprise environments; still requires correct application, backup, database, and firewall design.

### ASGI servers: Uvicorn, Daphne, Hypercorn

Use an ASGI server when the app needs WebSockets, async streaming, long-lived connections, or an async-first stack. Django supports ASGI, but ordinary synchronous Django pages do not automatically require it.

- **Uvicorn:** popular ASGI server, common with Django/Starlette/FastAPI.
- **Daphne:** originally associated with Django Channels and WebSockets.
- **Hypercorn:** ASGI/WSGI server with broader protocol options.

**Important:** ASGI is not a magic speed upgrade. It changes concurrency and operational behavior. Use it because your protocol needs it.

### Docker Compose

Docker Compose describes multi-service environments such as web, database, Redis, worker, and proxy in a versioned file.

**Advantages:** reproducible dependencies; developer/prod parity; useful for teams and multi-service apps.

**Trade-offs:** containers do not replace TLS, backups, security, or operations. They add image builds, registries, volume strategy, and container networking to learn.

### Managed PaaS

A Platform-as-a-Service deploys code/images and usually provides routing, TLS, logs, managed databases, or a built-in deployment pipeline.

**Advantages:** low operational burden, fast first deploy, managed network edge.

**Trade-offs:** cost, platform limits, provider-specific conventions, and still needing migrations/backups/secrets/observability.

### Kubernetes

Kubernetes schedules containers across machines and provides primitives for services, deployments, ingress, configuration, and scaling.

**Advantages:** powerful multi-service/multi-team operations at scale.

**Trade-offs:** substantial complexity. It is not the default answer for a single Django app. Start simpler and move only when operational needs justify it.

## A useful anti-pattern list

Avoid these without a specific reason:

- running `runserver` in production;
- exposing Gunicorn/Uvicorn directly to the public internet;
- exposing PostgreSQL port `5432` publicly;
- choosing Kubernetes only because it sounds professional;
- putting secrets in Git or Docker images;
- setting up two reverse proxies for one small site;
- adding Redis/Celery/containers before the application has a need for them.
