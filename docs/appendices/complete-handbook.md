# Complete all-in-one handbook

This appendix combines the current chapter pages. The chaptered pages remain the source of truth; this file is for offline reading, search, printing, and one-page review. > If a chapter and this appendix ever disagree, update the chapter first and regenerate this appendix from the navigation in `mkdocs.yml`.

---

<!-- Source: docs/index.md -->

# Django Production Deployment Guide

> A Read the Docs-ready, docs-as-code handbook for moving a bare Django project from a developer laptop to a secure, repeatable production service.

This guide is deliberately **explanatory**. It teaches what each layer is, why it exists, when to choose it, how the pieces communicate, how to configure them, and how to operate the system after launch.

## Who this is for

This book is intentionally written for people who can build a Django project but feel lost when it leaves their laptop. It does not assume that words like reverse proxy, systemd, TLS, socket, migration, worker, or environment variable are already obvious. When a command appears, the goal is to explain what layer it touches, what can go wrong, and how to verify it.

If you are experienced, you can skim the explanations and use the checklists. If you are new, read slowly and treat each code block as something to understand before you paste it. Production work becomes safer when you can explain every line you run.


You know basic Linux commands, Python, Git, and Django. You may never have deployed a public service before.

## What this book covers

- The request path: browser → DNS → firewall → reverse proxy → application server → Django → database.
- Django production configuration, static/media handling, secrets, migrations, and health checks.
- Major server stacks: **Nginx + Gunicorn**, **Apache + Gunicorn**, **Apache + mod_wsgi**, **Caddy + Gunicorn**, **ASGI with Uvicorn/Daphne/Hypercorn**, Docker Compose, managed platforms, and a practical introduction to Kubernetes.
- Ubuntu/VPS provisioning, SSH, UFW, Fail2Ban, TLS/Let’s Encrypt, systemd, PostgreSQL, monitoring, backup/restore, CI, staging, releases, and incident response.
- How to package the application as a responsible open-source project.

## Scope and honest boundaries

No book can enumerate every hosting provider, reverse proxy, cloud service, operating system, and framework combination. This one covers the **major architecture families** and gives you a decision process. The reference runbooks target a single Ubuntu VPS with PostgreSQL and a public domain; concepts transfer to other environments.

## Recommended first serious stack

For most conventional Django applications on one VPS:

```text
Browser
  → DNS
  → provider firewall
  → UFW
  → Nginx or Apache (HTTPS, static files, reverse proxy)
  → Gunicorn (private WSGI application server)
  → Django
  → PostgreSQL (private database)
```

Choose **Nginx + Gunicorn** when you want the common reverse-proxy path. Choose **Apache + Gunicorn** when Apache is already standard in your environment. Choose **Caddy + Gunicorn** when simple automatic HTTPS is a priority. Use **ASGI** only when your application needs WebSockets or other async/long-lived connections.

## Start here

1. Read [Mental model](../getting-started/production-mental-model.md).
2. Read [Choose your architecture](../getting-started/choose-a-stack.md).
3. Follow the [reference deployment path](../deployment-stacks/nginx-gunicorn-postgresql.md) for a first VPS deployment.
4. Do not skip [security](../operations/firewall-ssh-and-host-security.md), [backups](../operations/backups-and-disaster-recovery.md), or [open-source publication](../open-source/publishing-a-project.md).

## Read and publish the book

Use the chapter navigation to read online. Maintainers can follow [Publishing on Read the Docs](../read-the-docs-setup.md) to configure a hosted build.

## Safety rule

Every command is a template. Replace placeholders such as `<APP_NAME>`, `<DOMAIN>`, `<DEPLOY_USER>`, and `<PROJECT_PACKAGE>`. Read the explanation and verification step before applying it to a live system.

---

<!-- Source: getting-started/production-mental-model.md -->

# 1. The production mental model

A Django project is not “deployed” merely because `python manage.py runserver` is reachable from a browser. The development server is designed for feedback while writing code: it reloads automatically, exposes helpful errors, and assumes a trusted developer environment. A production system needs different guarantees:

- It starts after a reboot.
- It handles concurrent requests.
- It keeps secrets out of source control.
- It speaks HTTPS correctly.
- It keeps the database private.
- It can be updated, observed, backed up, and recovered deliberately.

## Production is a system of states

| State category | Examples | Put in Git? | Recovery method |
|---|---|---:|---|
| Source code | Python, templates, migrations, CSS, config templates | Yes | clone / checkout a commit or tag |
| Secrets | `SECRET_KEY`, API tokens, DB password | Never | protected transfer, secret manager, rotation |
| Database data | users, posts, orders, settings | No | verified database backup and restore |
| Uploaded media | images, documents, attachments | No | file/object-storage backup |
| Static build output | `collectstatic` result | Usually no | regenerate from code |
| Runtime state | sockets, PIDs, caches, service logs | No | recreate with systemd/services |

The most common deployment mistakes happen when a server contains **hidden state**: someone edited a settings file manually, a password only exists in one shell history, a database has no tested backup, or the server runs code that Git does not know about.

## The separation of responsibilities

A healthy small deployment usually splits roles:

```text
Public internet
  ↓
Reverse proxy / web server      handles TLS, static files, hostnames, client connections
  ↓
Application server              runs Python workers (Gunicorn/uWSGI/Uvicorn/Daphne)
  ↓
Django                          routes requests, authorizes users, renders responses
  ↓
PostgreSQL                      stores durable relational data
```

Each layer has a smaller job than “do everything.” That makes debugging traceable:

- A certificate error is usually DNS/TLS/web-server territory.
- A `502` usually means proxy → app-server connectivity.
- A `500` usually means Django code, configuration, or database.
- A missing CSS file usually means static file configuration.
- A `403 CSRF` usually means browser origin, proxy HTTPS headers, or cookie/security settings.

## The operating principle: inspect before you mutate

Before changing a server, inspect its current state:

```bash
systemctl status <service>
sudo ufw status numbered
sudo nginx -t              # when Nginx is used
sudo apache2ctl configtest # when Apache is used
git status --short --branch
```

Make one change at a time, verify it, and keep a recovery path. This book favors small, reversible operations over one enormous copy-paste block.

## What “secure enough” means

There is no absolute finish line called “secure.” For a small public Django service, a serious baseline means:

- supported OS packages are patched,
- SSH uses keys and root login is disabled after verification,
- only necessary inbound ports are open,
- PostgreSQL and application ports are not public,
- secrets are outside Git and readable only by necessary accounts,
- HTTPS is on and renewal is tested,
- Django production checks are clean or consciously reviewed,
- backups are automated, verified, and copied off the host,
- logs and an incident runbook exist.

## How to read commands in this book

A terminal command is not magic. It is a request to change or inspect one layer of the system. Before running a command, identify four things:

| Question | Example |
|---|---|
| Who runs it? | root through `sudo`, the deploy user, the app user, or `postgres` |
| Where is it run? | your laptop, the VPS shell, inside a container, or inside PostgreSQL |
| What does it change? | files, packages, services, database schema, firewall rules, or only output |
| How do you verify it? | `systemctl status`, `nginx -t`, `curl`, `journalctl`, `psql`, or a browser |

For example:

```bash
sudo systemctl restart <APP_NAME>
```

This is a server command. `sudo` means it asks for administrator privileges. `systemctl` talks to systemd. `restart` stops and starts the service. `<APP_NAME>` is a placeholder for the service unit name. The command does not deploy code by itself; it only tells the already-installed service to start again using the files and environment currently on disk.

A safe follow-up is:

```bash
sudo systemctl status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 50 --no-pager
```

The first command asks whether systemd thinks the service is running. The second shows recent logs. If the restart failed, the logs usually explain whether the cause was Python import failure, missing environment variable, database connection error, bad permissions, or a crashed worker.

## Placeholders are not optional thinking

Angle-bracket values such as `<APP_NAME>`, `<DOMAIN>`, `<APP_USER>`, and `<DB_NAME>` are placeholders. Replace them consistently with your real values. Do not leave angle brackets in real config files unless the tool explicitly expects them.

A good private deployment note might say:

```text
APP_NAME=exampleapp
PROJECT_PACKAGE=config
DOMAIN=example.com
WWW_DOMAIN=www.example.com
DEPLOY_USER=deploy
APP_USER=exampleapp
DB_NAME=exampleapp_prod
DB_USER=exampleapp_user
```

When a later command says `/srv/<APP_NAME>/venv/bin/python`, you should mentally translate it to `/srv/exampleapp/venv/bin/python`. This habit prevents many copy/paste mistakes.

---

<!-- Source: getting-started/request-journey.md -->

# 2. The request journey

Consider a browser visiting:

```text
https://example.com/blogs/42/
```

A working request follows this path:

```text
1. Browser asks DNS for example.com.
2. DNS returns an IP address.
3. Browser opens TCP port 443 on that IP.
4. Provider firewall and host firewall decide whether it may enter.
5. Nginx, Apache, or Caddy receives the TLS connection.
6. The web server proves its identity with a certificate and decrypts HTTP.
7. A static request is served directly; a dynamic request is proxied internally.
8. Gunicorn/uWSGI/Uvicorn/Daphne calls Django through WSGI or ASGI.
9. Django resolves URL → view → permissions → database work → response.
10. The response travels back through the same layers.
```

## Why the extra layers are useful

It may look simpler to expose Django directly. Production layers exist because they are specialists:

| Component | Specialist responsibility |
|---|---|
| DNS | Human name to network address |
| Reverse proxy | TLS, redirects, static files, client connection handling, access logs |
| App server | Python worker lifecycle and WSGI/ASGI protocol |
| Django | application rules, forms, ORM, authorization, config-examples/API |
| PostgreSQL | durable transactions, indexes, concurrent data access |
| systemd | start on boot, restart after failure, service logs |

This division also reduces attack surface. Only ports 80 and 443 should usually be public. The app server can listen on `127.0.0.1` or a Unix socket; PostgreSQL can listen only locally or on a private network.

## A debugging map

| Symptom | Most likely layer | First commands/questions |
|---|---|---|
| Domain cannot be resolved | DNS | `dig example.com`, record/TTL/registrar check |
| Connection timed out | provider firewall/UFW/service | provider network rules, `ufw status`, `systemctl status` |
| Certificate warning | DNS/TLS/vhost | does DNS point to correct server? does certificate include hostname? |
| `502 Bad Gateway` | proxy → app server | is Gunicorn/Uvicorn running? correct bind/socket? proxy error log? |
| `500 Server Error` | Django/DB | `journalctl -u <app-service>`, Django error traceback |
| `404` for only one object | app URL/data query | generated URL, `slug`, date/timezone, filters |
| CSS/JS missing | static config | `collectstatic`, `alias`, permissions, browser network tab |
| CSRF 403 | HTTPS/proxy/settings | current origin, secure cookie, forwarded proto, trusted origins |
| site dies after reboot | systemd | `systemctl is-enabled <service>` |

Do not jump to application code when the network layer is failing, and do not open ports when the issue is a bad URL pattern. Trace the request from the outside inward.

---

<!-- Source: getting-started/choose-a-stack.md -->

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

---

<!-- Source: getting-started/variables-and-layout.md -->

# 4. Variables and target layout

Every config in this book uses placeholders. Define them once before editing files.

| Placeholder | Example | Meaning |
|---|---|---|
| `<APP_NAME>` | `myproject` | service/directory/database naming prefix |
| `<PROJECT_PACKAGE>` | `myproject` | Python package containing `settings.py`, `wsgi.py`, `asgi.py` |
| `<DOMAIN>` | `example.com` | canonical public hostname |
| `<WWW_DOMAIN>` | `www.example.com` | optional alternate hostname |
| `<DEPLOY_USER>` | `deploy` | SSH/Git maintenance account |
| `<APP_USER>` | `myproject` | non-login Linux user that runs Python service |
| `<DB_NAME>` | `myproject` | PostgreSQL database |
| `<DB_USER>` | `myproject_db` | PostgreSQL login role |

## Suggested single-VPS layout

```text
/srv/<APP_NAME>/
├── app/               # Git checkout
├── venv/              # Python virtual environment
├── staticfiles/       # collectstatic output
└── media/             # user uploads, if you use local media

/etc/<APP_NAME>/
├── <APP_NAME>.env     # secrets/environment; not Git
└── ...                # optional DB service/pass files

/run/<APP_NAME>/       # runtime socket/PID directory created by systemd

/var/backups/<APP_NAME>/
└── postgresql/        # database dump files, private permissions
```

## Why use distinct users?

A useful split is:

- `<DEPLOY_USER>` owns the Git checkout and runs Git operations.
- `<APP_USER>` runs Gunicorn/Uvicorn/Django and only needs read access to code plus write access where Django actually writes.
- `postgres` runs the database service and owns database backups if you use local peer-authenticated backup jobs.
- `www-data` or the web-server user needs read access to static/media directories only.

This is least privilege in practice: a compromised process should not automatically inherit the ability to edit source code, read every secret, or manage the entire server.

## Naming discipline matters

Use the same app prefix in service names, directories, database names, backup paths, and log names. A future you should be able to answer “which service owns this file?” from the name alone.

---

<!-- Source: django-application/repository-and-dependencies.md -->

# 5. Repository hygiene and dependencies

A production deployment begins before the server exists. The repository should reproduce **code**, not contain production secrets or runtime artifacts.

## Minimum repository structure

```text
myproject/
├── manage.py
├── pyproject.toml or requirements.txt
├── myproject/
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── web/
├── config-examples/
├── static/
├── deploy/                 # public config-examples/scripts only
├── docs/
├── README.md
├── LICENSE
├── SECURITY.md
└── .gitignore
```

## What belongs in Git

Commit:

- source code, templates, migrations, static source files;
- dependency declaration/lock files;
- non-secret deployment templates;
- documentation, tests, CI configuration;
- `.env.example` with placeholder values.

Do **not** commit:

- production `.env` files;
- `SECRET_KEY`, tokens, private keys, database passwords;
- virtual environments, `__pycache__`, SQLite production data, generated `staticfiles`, user uploads, socket/PID files;
- server-specific Apache/Nginx config containing secrets.

## Example `.gitignore`

```gitignore
# Python
__pycache__/
*.py[cod]
.venv/
venv/

# Django runtime state
*.sqlite3
staticfiles/
media/

# Secrets
.env
.env.*
!.env.example

# Editor/OS
.vscode/
.idea/
.DS_Store
```

## Dependency management choices

You need a reproducible answer to “which versions did production run?”

| Option | Good for | Key point |
|---|---|---|
| `requirements.txt` | simple Django projects | pin direct and/or resolved versions deliberately |
| `pip-tools` | pip workflow with compiled lock files | maintain input requirements and generated lock output |
| Poetry | projects wanting lockfile + packaging workflow | use `pyproject.toml` and `poetry.lock` |
| uv | fast modern Python workflow | commit its lock file and document commands |

The tool matters less than committing the resolved dependency state and using the same file locally, in CI, and in deployment.

## Local pre-deploy quality gate

Before pushing a release:

```bash
python manage.py test
python manage.py check
python manage.py check --deploy  # review warnings in production-like settings
python manage.py makemigrations --check --dry-run
```

Then inspect Git:

```bash
git status --short
git diff --check
git log -1 --oneline
```

A clean working tree does not prove the app is correct; it proves you know which code you are about to ship.

## Migrations are production changes

A migration is code that changes data structure. Treat it as part of the release, not an afterthought.

- Review generated migrations.
- Think about table size and locks for large databases.
- Back up before risky migrations.
- Have a rollback/forward-fix plan.
- Never edit a migration that has already been applied to shared production history unless you understand the consequences.

---

<!-- Source: django-application/production-settings-and-secrets.md -->

# 6. Production settings and secrets

Django settings are where local development assumptions become explicit production behavior.

## Secrets versus configuration

Configuration answers “how should this deployment behave?” Examples: allowed hosts, whether HTTPS is used, email sender.

Secrets answer “what proves identity or grants access?” Examples: `SECRET_KEY`, DB password, API token, SMTP/App Script token.

Both should usually be supplied through protected environment variables. Only secrets are inherently sensitive, but keeping all deployment-specific values outside the code makes one repository usable across development, staging, and production.

## Minimal environment file

Create a **real** file outside Git, e.g. `/etc/<APP_NAME>/<APP_NAME>.env`:

```dotenv
DJANGO_SECRET_KEY='replace-with-a-long-random-value'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=<DOMAIN>,<WWW_DOMAIN>
DJANGO_CSRF_TRUSTED_ORIGINS=https://<DOMAIN>,https://<WWW_DOMAIN>
DJANGO_USE_HTTPS=True

POSTGRES_DB=<DB_NAME>
POSTGRES_USER=<DB_USER>
POSTGRES_PASSWORD='replace-me'
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432

DEFAULT_FROM_EMAIL='My Project <noreply@<DOMAIN>>'
```

Use restrictive ownership/permissions:

```bash
sudo install -d -o root -g <APP_USER> -m 750 /etc/<APP_NAME>
sudo install -o root -g <APP_USER> -m 640 /dev/null /etc/<APP_NAME>/<APP_NAME>.env
sudoedit /etc/<APP_NAME>/<APP_NAME>.env
```

## Example settings pattern

```python
# <PROJECT_PACKAGE>/settings.py
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}

def env_list(name: str, default: str = "") -> list[str]:
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = env_bool("DJANGO_DEBUG", False)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ["POSTGRES_DB"],
        "USER": os.environ["POSTGRES_USER"],
        "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": 60,
    }
}

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

USE_HTTPS = env_bool("DJANGO_USE_HTTPS", False)
SECURE_SSL_REDIRECT = USE_HTTPS
SESSION_COOKIE_SECURE = USE_HTTPS
CSRF_COOKIE_SECURE = USE_HTTPS
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
REFERRER_POLICY = "same-origin"
```

## Reverse-proxy HTTPS awareness

When Nginx/Apache/Caddy terminates HTTPS and speaks HTTP to Gunicorn, Django otherwise sees the internal hop as HTTP. Set this **only when the proxy reliably sets the header**:

```python
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

And set the header in the proxy configuration. Misconfiguring this can create redirect loops or cause Django to trust a spoofed header if Gunicorn is publicly reachable. The protection is: bind the app server to `127.0.0.1`/Unix socket and let only your proxy reach it.

## HSTS comes later

HSTS tells browsers to prefer HTTPS for a period. Start with `SECURE_HSTS_SECONDS = 0` or omit it until HTTPS, redirects, and all subdomains are proven stable. Then enable a short period first, validate, and increase deliberately. Do not preload/include subdomains casually.

## Security checks

Run with production variables loaded:

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check --deploy
'
```

Warnings are prompts to understand a decision, not instructions to silence everything blindly.

## Line-by-line explanation of the settings pattern

This section explains the earlier settings example as if you are seeing production settings for the first time.

```python
import os
from pathlib import Path
```

`os` lets Python read environment variables such as `DJANGO_SECRET_KEY` and `POSTGRES_PASSWORD`. `Path` gives a clean way to build filesystem paths without hard-coding slash behavior.

```python
BASE_DIR = Path(__file__).resolve().parent.parent
```

`__file__` is the current settings file. `resolve()` turns it into an absolute path. `parent.parent` walks up to the project base directory. Django uses `BASE_DIR` later for paths such as static files and media files.

```python
def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}
```

Environment variables are strings. Without conversion, the string `"False"` is still truthy in Python. This helper turns common text values into a real boolean. `DJANGO_DEBUG=False` becomes `False`; `DJANGO_DEBUG=true` becomes `True`.

```python
def env_list(name: str, default: str = "") -> list[str]:
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]
```

Some Django settings expect a list. The environment file stores `DJANGO_ALLOWED_HOSTS=example.com,www.example.com` as one string. This helper splits it at commas, trims spaces, and removes empty values.

```python
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
```

Square brackets mean the setting is required. If the environment variable is missing, Django crashes at startup instead of running with an unsafe fake value. That is good. A missing production secret should be loud.

```python
DEBUG = env_bool("DJANGO_DEBUG", False)
```

`DEBUG` controls detailed error pages and other development behavior. In production it must be false. The default is false so forgetting the variable does not accidentally expose debug pages.

```python
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
```

Django checks the HTTP `Host` header against this list. If your domain is `example.com`, include `example.com`. If you also serve `www.example.com`, include that too. Do not use `*` in normal production because it disables an important host-header protection.

```python
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")
```

This tells Django which HTTPS origins are allowed to submit unsafe requests such as POST forms. Values include the scheme, for example `https://example.com`, not only the hostname.

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ["POSTGRES_DB"],
        "USER": os.environ["POSTGRES_USER"],
        "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": 60,
    }
}
```

`ENGINE` selects Django's PostgreSQL backend. `NAME`, `USER`, and `PASSWORD` identify the database and role. `HOST=127.0.0.1` means PostgreSQL is on the same server. `PORT=5432` is PostgreSQL's normal TCP port. `CONN_MAX_AGE=60` lets Django reuse a database connection briefly instead of opening a new one for every request.

```python
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
```

`STATIC_URL` is the browser URL prefix. `STATIC_ROOT` is the directory where `collectstatic` gathers CSS, JavaScript, images, and admin assets. Nginx or Apache serves this directory directly.

```python
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
```

Media files are user-uploaded files. They are not the same as static files. They need a backup plan because users create them after deployment.

```python
USE_HTTPS = env_bool("DJANGO_USE_HTTPS", False)
SECURE_SSL_REDIRECT = USE_HTTPS
SESSION_COOKIE_SECURE = USE_HTTPS
CSRF_COOKIE_SECURE = USE_HTTPS
```

These settings switch on HTTPS behavior when the deployment is ready. `SECURE_SSL_REDIRECT` redirects HTTP to HTTPS. The cookie settings tell browsers to send session/CSRF cookies only over HTTPS.

```python
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
REFERRER_POLICY = "same-origin"
```

These are browser security headers. They reduce common classes of mistakes: MIME sniffing, clickjacking, and leaking full referrer URLs across sites.

## Why the environment file is outside Git

A Git repository is copied to laptops, CI systems, GitHub, backups, and sometimes forks. Secrets do not belong there. The application code should say, "I need `POSTGRES_PASSWORD`." The server environment should supply the actual value.

This separation lets you run the same code in multiple places:

| Environment | Same code? | Different values? |
|---|---|---|
| local development | yes | local database, debug true |
| staging | yes | staging domain, staging secrets |
| production | yes | production domain, production secrets |

If a secret leaks, rotate the secret. Do not only delete it from the latest commit; Git history may still contain it.

---

<!-- Source: django-application/static-media-migrations-health-checks.md -->

# 7. Static files, media, migrations, and health checks

## Static files and media are not the same

| Type | Examples | Source of truth | Production strategy |
|---|---|---|---|
| Static files | CSS, JavaScript, logos shipped with code | Git repository | `collectstatic`, then serve directly via proxy/web server |
| Media files | user uploads, avatars, attachments | runtime data | persistent storage and backup; often object storage later |

`collectstatic` gathers app-level static source into `STATIC_ROOT`. It does **not** handle user uploads and it does not replace a web server.

## Run collectstatic deliberately

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
'
```

Run it when static sources or static settings change. You do not need it for an ordinary Python-only fix.

## Migrations

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
'
```

Run it only when a new migration is part of the release. It is safe to include in a standard runbook for small apps, but understand that large or complex migrations can lock tables or take time.

## Add a tiny health endpoint

A health endpoint gives monitors and operators a stable request to test. Keep it simple; do not expose secrets or expensive queries.

```python
# web/views.py
from django.http import JsonResponse

def healthz(request):
    return JsonResponse({"status": "ok"})
```

```python
# <PROJECT_PACKAGE>/urls.py
from django.urls import path
from web.views import healthz

urlpatterns = [
    path("healthz/", healthz, name="healthz"),
]
```

A deeper readiness check may test database connectivity, but distinguish it from a lightweight liveness check. A health page that always queries external APIs can create an outage amplifier.

## Production smoke test

After deployment, verify:

```bash
curl -fsS https://<DOMAIN>/healthz/
curl -I https://<DOMAIN>/
```

Then exercise one critical authenticated path manually or with browser automation: login, create/update a representative record, and inspect the expected response.

---

<!-- Source: django-application/wsgi-and-asgi.md -->

# 8. WSGI and ASGI explained

Django exposes two entry points in a default project:

```text
<PROJECT_PACKAGE>/wsgi.py
<PROJECT_PACKAGE>/asgi.py
```

They are interfaces, not alternative copies of your application.

## WSGI

WSGI is the traditional Python web-server gateway interface. It fits normal request/response Django applications: HTML pages, REST APIs, forms, admin, and most CRUD workloads.

Typical WSGI app servers:

- Gunicorn
- uWSGI
- Apache mod_wsgi

Use WSGI when your application does not require WebSockets or other long-lived async protocols.

## ASGI

ASGI supports asynchronous protocols and long-lived connections in addition to ordinary HTTP.

Typical ASGI servers:

- Uvicorn
- Daphne
- Hypercorn

Use ASGI when you need one or more of these:

- WebSockets (chat, collaborative editing, live dashboards),
- server-sent events or streaming patterns,
- async integrations that benefit from non-blocking I/O,
- Django Channels or another ASGI-native component.

## What async does not change

ASGI does not remove the need for:

- a reverse proxy/TLS layer,
- private databases,
- environment variables and secrets,
- systemd/containers for process supervision,
- backups, monitoring, tests, and security headers.

It also does not automatically make blocking ORM work “async.” Design and measure before changing the whole stack for performance reasons.

## The simple rule

Start with WSGI/Gunicorn for a conventional Django site. Adopt ASGI because a feature needs it, not because it is newer.

---

<!-- Source: django-application/email-background-tasks-and-services.md -->

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

---

<!-- Source: server-setup/vps-dns-and-provider-controls.md -->

# 10. VPS, Ubuntu, DNS, and provider controls

## VPS responsibilities

A VPS is a virtual machine rented from a provider. It gives you a public IP, CPU, memory, disk, and an operating system. In return, you own the operating responsibility: patches, network policy, secrets, backups, logs, and recovery.

A managed platform reduces some of this responsibility. It does not eliminate application configuration, migrations, data backups, or access control.

## Before deployment: where the app actually runs

A beginner-friendly production path usually looks like this:

```text
Your laptop
  -> Git repository
  -> VPS or platform
  -> public internet
```

The laptop is where you write code and run tests. Git is the transport and history system. The VPS is the always-on computer that runs the application, database, web server, background workers, and scheduled jobs. The internet reaches the VPS through a public IP address and DNS name.

Common hosting choices:

| Option | Best fit | Responsibility level |
|---|---|---|
| VPS | learning, small products, full control | high: OS, firewall, backups, services |
| Dedicated server | predictable heavy workloads | very high: hardware/provider coordination too |
| PaaS | teams that want less server administration | medium: app config, data, vendor limits |
| Managed database + app VPS | growing apps with valuable data | medium-high: app server plus database contract |
| Kubernetes | many services, platform team, container orchestration | very high unless managed and justified |

Choose the smallest boring server that can run the app comfortably, then document how to resize or migrate. For a modest Django app, 1-2 vCPU, 1-2 GB RAM, and SSD storage is often enough to start if PostgreSQL and background workers are not heavy. Watch memory and disk before upgrading CPU.

## DNS before certificates

For a normal public TLS certificate, the domain must resolve to the server that will answer the validation challenge.

Create DNS records first:

```text
A     <DOMAIN>       → <SERVER_IPV4>
A     <WWW_DOMAIN>   → <SERVER_IPV4>  # optional
```

Verify from a resolver:

```bash
dig +short <DOMAIN>
dig +short <WWW_DOMAIN>
```

DNS is only a name-to-address system. It does not proxy traffic unless you deliberately enable a CDN/proxy service. A CDN can add caching, DDoS controls, and TLS termination, but it introduces another layer whose origin connection must be configured and tested.

## IP addresses and DNS records

A public IP address identifies the server on the internet. A private IP address is reachable only inside a private network. A domain is just a human name until DNS records point it somewhere.

Useful records:

| Record | Purpose | Example use |
|---|---|---|
| A | hostname to IPv4 address | `example.com -> 203.0.113.10` |
| AAAA | hostname to IPv6 address | `example.com -> 2001:db8::10` |
| CNAME | hostname alias to another hostname | `www -> example.com` |
| MX | mail routing | receiving email for the domain |
| TXT | verification and email policy | SPF, DKIM, DMARC, provider checks |

Set DNS TTLs deliberately. A short TTL can help during migration, but it does not make every resolver update instantly. Plan DNS changes before certificate issuance, launch windows, and provider migrations.

## Provider firewall versus UFW

Use two boundaries:

1. **Provider firewall/security group** — filters before traffic reaches the VPS.
2. **UFW host firewall** — filters on the Linux host.

For a simple web app, allow only:

```text
TCP 22    SSH administration
TCP 80    HTTP redirect and ACME validation
TCP 443   HTTPS application traffic
```

Do not open:

```text
5432  PostgreSQL
8000  Django development server
8001  Gunicorn/Uvicorn app server
6379  Redis
```

unless you have an explicit private-network architecture and source-IP restrictions.

## The network path in production

For a classic single-server deployment, the request path is:

```text
Browser
  -> DNS lookup
  -> public IP address
  -> provider firewall
  -> UFW on the VPS
  -> TCP port 443
  -> Nginx/Apache/Caddy
  -> Unix socket or localhost TCP port
  -> Gunicorn/Uvicorn
  -> Django
  -> PostgreSQL on localhost/private network
```

Key terms:

| Term | Meaning in deployment |
|---|---|
| TCP | transport protocol used by HTTP(S), SSH, PostgreSQL, Redis, and many APIs |
| port | numbered entry point on an IP address, such as 22, 80, 443, 5432 |
| socket | endpoint for process communication; can be TCP or Unix file socket |
| localhost | the same machine, usually `127.0.0.1` or `::1` |
| public IP | routable from the internet |
| private IP | reachable only inside a private network/VPC/LAN |
| NAT | address translation between private networks and public routes |
| proxy | server that receives a request and forwards it to another service |
| CDN | edge network that can cache, proxy, and protect public traffic |

When debugging, move along this path one layer at a time. Do not start by changing Django settings if DNS does not resolve, port 443 is blocked, or the proxy cannot reach the app server.

## Start with an LTS release

Use a supported Ubuntu LTS release and apply security updates. Record the OS release and provider details in private operations documentation so a future migration is reproducible.

## Provider controls to record

Keep a private operations note for each production server:

- provider and region;
- server size and disk size;
- public IPv4/IPv6 addresses;
- private network/VPC name if used;
- firewall/security group rules;
- DNS provider and authoritative nameservers;
- backup/snapshot settings;
- emergency access method.

This documentation matters during incidents. If the original deployer is unavailable, another maintainer should know where the server lives and which control panels can affect it.

---

<!-- Source: server-setup/ssh-users-and-permissions.md -->

# 11. SSH, users, permissions, and directories

## First login baseline

```bash
sudo apt update
sudo apt upgrade
sudo apt install -y git curl ca-certificates build-essential python3 python3-venv python3-pip
```

Do not apply a firewall lockout from a fragile connection. Keep one working SSH session open while testing another.

## Use SSH keys before disabling passwords

On your local machine:

```bash
ssh-keygen -t ed25519 -C "your-email@example.com"
ssh-copy-id <DEPLOY_USER>@<SERVER_IP>
```

Test a second SSH login using the key. Only then consider hardening `/etc/ssh/sshd_config.d/99-hardening.conf`:

```text
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
```

Validate and reload carefully:

```bash
sudo sshd -t
sudo systemctl reload ssh
```

Do not close the original session until a fresh key-based session succeeds.

## Create identities

```bash
sudo adduser <DEPLOY_USER>
sudo usermod -aG sudo <DEPLOY_USER>

sudo adduser --system --group --home /srv/<APP_NAME> --shell /usr/sbin/nologin <APP_USER>
```

`<DEPLOY_USER>` is a human/operator account. `<APP_USER>` is a non-login service identity that runs the Python application.

## Create directories

```bash
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>/app
sudo install -d -o <APP_USER> -g www-data -m 2750 /srv/<APP_NAME>/staticfiles
sudo install -d -o <APP_USER> -g www-data -m 2750 /srv/<APP_NAME>/media
```

The setgid bit in `2750` helps new files inherit the directory group. Adjust only based on actual access needs.

## Understand permissions

For `750`:

```text
owner: read/write/enter
 group: read/enter
other: no access
```

Files containing secrets should commonly be `640` or stricter. Runtime files should not be world-writable. Avoid `chmod 777`; it hides an ownership design problem rather than solving it.

## Clone application code

Run Git as the deploy user, not root:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>
git clone <REPOSITORY_URL> app
python3 -m venv /srv/<APP_NAME>/venv
/srv/<APP_NAME>/venv/bin/pip install --upgrade pip
/srv/<APP_NAME>/venv/bin/pip install -r app/requirements.txt
'
```

Then grant the app service read/execute access to code without making it the repository owner:

```bash
sudo chgrp -R <APP_USER> /srv/<APP_NAME>/app
sudo chmod -R g+rX /srv/<APP_NAME>/app
```

Adapt this rule if your deployment user needs to keep exclusive ownership; the principle is that application code should be readable by the runtime user, while Git operations remain controlled.

## What the first package commands do

```bash
sudo apt update
```

This downloads the latest package index from Ubuntu repositories. It does not upgrade software by itself; it refreshes the server's knowledge of available versions.

```bash
sudo apt upgrade
```

This applies available upgrades. On a new server, run it early so you are not building on stale packages.

```bash
sudo apt install -y git curl ca-certificates build-essential python3 python3-venv python3-pip
```

This installs the basic tools the deployment needs:

| Package | Why it is installed |
|---|---|
| `git` | downloads and updates your source code |
| `curl` | tests HTTP endpoints from the terminal |
| `ca-certificates` | lets tools trust public HTTPS certificates |
| `build-essential` | compiles Python packages that need native extensions |
| `python3` | runs Python |
| `python3-venv` | creates an isolated virtual environment |
| `python3-pip` | installs Python packages |

The `-y` flag answers yes to the install prompt. Use it only when you understand the package list.

## Why there are two Linux users

A common beginner mistake is to run everything as `root` because it avoids permission errors. That works until a bug, stolen key, or bad command has unlimited power.

This guide separates identities:

| Identity | Job | Should it log in by SSH? |
|---|---|---|
| `<DEPLOY_USER>` | human deploys code and runs admin commands with sudo | yes |
| `<APP_USER>` | systemd runs Django/Gunicorn with limited permissions | no |
| `www-data` | Nginx/Apache reads public files | no |
| `postgres` | PostgreSQL administration role on the OS | no normal app login |

The app user should be able to read code and write only what the app truly needs, such as local media if you use local media storage. It should not own your whole server.

## Understanding the `install -d` directory commands

```bash
sudo install -d -o <DEPLOY_USER> -g <APP_USER> -m 750 /srv/<APP_NAME>/app
```

Read it piece by piece:

| Piece | Meaning |
|---|---|
| `sudo` | run with administrator privileges |
| `install -d` | create a directory with exact ownership and permissions |
| `-o <DEPLOY_USER>` | make the deploy user the owner |
| `-g <APP_USER>` | make the app user group the group owner |
| `-m 750` | owner can read/write/enter; group can read/enter; others get no access |
| `/srv/<APP_NAME>/app` | the target directory for the application repository |

This is more precise than `mkdir` followed by several `chown` and `chmod` commands.

## Why `g+rX` is used for code

```bash
sudo chmod -R g+rX /srv/<APP_NAME>/app
```

`g+rX` means "give the group read permission, and give execute permission only to directories and already-executable files." Directories need execute permission so a process can enter them. Normal Python files need read permission, not execute permission.

This lets `<APP_USER>` import Python code without making every file executable.

---

<!-- Source: server-setup/postgresql.md -->

# 12. PostgreSQL: the private data layer

PostgreSQL is a relational database server. Django’s ORM translates model operations into SQL, while PostgreSQL handles durable storage, transactions, concurrent access, indexes, constraints, and backups.

## Why PostgreSQL instead of SQLite in production?

SQLite is excellent for local prototypes and small single-process projects. PostgreSQL is a more appropriate default for a multi-user production web application because it handles concurrent writes, roles, backups, transactions, and operational tooling more predictably.

## Install packages

```bash
sudo apt install -y postgresql postgresql-contrib libpq-dev
```

## Create a dedicated database and role

```bash
sudo -u postgres psql
```

Inside PostgreSQL:

```sql
CREATE ROLE <DB_USER> LOGIN PASSWORD 'use-a-unique-long-password';
CREATE DATABASE <DB_NAME> OWNER <DB_USER>;
\q
```

Do not use the `postgres` superuser as your Django database user. The application role should own only what it needs.

## Keep PostgreSQL private

For a single-VPS deployment, Django and PostgreSQL communicate locally. Do not add a public UFW rule for port 5432. Do not bind PostgreSQL to public interfaces unless you have a private-network database architecture, TLS, source restriction, and a documented reason.

## Authentication and `pg_hba.conf`

PostgreSQL has two separate controls: roles inside the database server and connection rules in `pg_hba.conf`. A role may exist, but a connection can still be rejected if the host, database, user, or authentication method is not allowed.

For a single-VPS deployment, prefer local connections. Keep `listen_addresses` limited to localhost unless you intentionally use a private database network. If you edit PostgreSQL configuration, reload the service and verify with a real Django connection rather than assuming the file is correct.

```bash
sudo systemctl reload postgresql
sudo -u <APP_USER> -H bash -lc 'cd /srv/<APP_NAME>/app && /srv/<APP_NAME>/venv/bin/python manage.py dbshell'
```

## Least-privilege roles

The Django role usually owns the application database and should not be a PostgreSQL superuser. For larger teams, create separate roles for:

| Role | Purpose |
|---|---|
| app role | Django runtime migrations and queries |
| read-only role | analytics or support inspection |
| backup role | dump/replication privileges as needed |
| admin role | controlled maintenance, not used by the app |

Store each credential separately. Do not share the app role password with dashboards, notebooks, or ad hoc scripts.

## Connection pooling

Each Gunicorn/Uvicorn worker can hold database connections. Background workers and management commands add more. If traffic grows, PostgreSQL can run out of connections before CPU is saturated.

Options:

- keep Django `CONN_MAX_AGE` modest and measure connection count;
- tune web worker counts based on memory and database capacity;
- add PgBouncer when connection churn or count becomes a real limit;
- use a managed database pooler if your provider offers one.

Connection pooling is not a substitute for slow-query fixes. Indexes, pagination, and query shape still matter.

## Backups and restore testing

A backup that has never been restored is only a guess. Test restoration into a separate database before you need it during an incident.

Minimum practice:

```text
Nightly logical dump
  -> compressed file
  -> off-server storage
  -> retention policy
  -> scheduled restore drill
```

Record the PostgreSQL version, dump command, restore command, encryption method if used, retention window, and the last successful restore test date.

## Migrations in production

Treat migrations as code, but remember they change data structures. Before deploying risky migrations, ask:

- Does this lock a large table?
- Can old code and new code run during the transition?
- Is there a data backfill, and can it run in batches?
- Is rollback a code rollback, a reverse migration, or a restore?
- Has this migration run against staging data of realistic size?

For large systems, use expand-and-contract migrations: add nullable/new structures first, deploy compatible code, backfill safely, then remove old structures later.

## Basic tuning signals

Do not copy random tuning values. Start by measuring:

| Signal | What it may indicate |
|---|---|
| slow queries | missing indexes, inefficient ORM patterns, too much data per request |
| high connection count | too many workers, missing pooling, long transactions |
| disk growth | missing retention, large uploads in DB, audit/log tables |
| high I/O wait | storage bottleneck, inefficient queries, undersized server |
| lock waits | migration/table lock, long transaction, concurrent writes |

Add indexes with migrations, verify query plans when needed, and keep database monitoring close to deployment history.

## Verify Django connection

After environment variables and dependencies are configured:

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
'
```

## Database lifecycle rules

- Schema changes are Django migrations in Git.
- Data is not in Git; it is protected by backup/restore.
- Test restores into a separate database.
- Do not run application management commands as `root`; run them as the app service identity with real production environment variables loaded.
- Keep the database version and backup format documented before a server migration.

---

<!-- Source: server-setup/systemd-and-environment.md -->

# 13. systemd and environment files

`systemd` is the service manager on modern Ubuntu. It starts services at boot, restarts failed services according to policy, records journal logs, and provides a stable operational interface.

## Why not `nohup gunicorn ... &`?

A background shell process has no structured restart policy, weak logging, unclear ownership, and does not reliably survive reboots. systemd makes the process an explicit system service.

## Environment file pattern

```ini
# /etc/<APP_NAME>/<APP_NAME>.env
DJANGO_SECRET_KEY='...'
DJANGO_DEBUG=False
POSTGRES_DB=<DB_NAME>
POSTGRES_USER=<DB_USER>
POSTGRES_PASSWORD='...'
```

A systemd service can load it with:

```ini
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
```

This is not encrypted storage. Its safety comes from permissions and host access control. A secret manager can replace it later, but a permission-controlled environment file is a useful small-VPS baseline.

## Service lifecycle commands

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now <APP_NAME>
sudo systemctl restart <APP_NAME>
sudo systemctl status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo journalctl -u <APP_NAME> -f
```

## Important service design rules

- Run the service as `<APP_USER>`, never root.
- Set `WorkingDirectory` so relative paths behave predictably.
- Use absolute executable paths (`/srv/.../venv/bin/gunicorn`).
- Keep application port/socket private.
- Use `Restart=on-failure` for resilience, not to hide a persistent crash.
- Use `systemctl status` and the journal to understand failure before repeatedly restarting.

## What systemd is doing for you

When you create `/etc/systemd/system/<APP_NAME>.service`, you are teaching the operating system how to run your app. Instead of depending on a terminal window, systemd becomes responsible for the process.

It handles:

- starting the app at boot;
- restarting it when it crashes if policy allows;
- attaching logs to the system journal;
- running the process as the correct Linux user;
- ordering startup after basic dependencies such as networking;
- giving operators one consistent command interface.

## Explain the lifecycle commands

```bash
sudo systemctl daemon-reload
```

Systemd does not reread every unit file on every command. After adding or editing a `.service` file, `daemon-reload` tells systemd to reload unit definitions from disk.

```bash
sudo systemctl enable --now <APP_NAME>
```

`enable` means "start this service automatically at boot." `--now` means "also start it immediately." Without `--now`, the service may be enabled for the next reboot but not running yet.

```bash
sudo systemctl restart <APP_NAME>
```

This stops and starts the service. Use it after code or environment changes that require a fresh Python process.

```bash
sudo systemctl status <APP_NAME>
```

This shows whether systemd thinks the service is active, failed, restarting, or disabled. It also shows the main process ID and recent log lines.

```bash
sudo journalctl -u <APP_NAME> -n 100 --no-pager
```

This reads the last 100 journal lines for that service. `--no-pager` prints directly to the terminal, which is easier to copy into notes.

```bash
sudo journalctl -u <APP_NAME> -f
```

This follows new logs live. Use it in one terminal while making a request from another terminal or browser.

## Reading a service failure

If a service fails, do not immediately change random settings. Read the first real error. Common examples:

| Log clue | Likely meaning |
|---|---|
| `KeyError: 'DJANGO_SECRET_KEY'` | environment file is missing a required variable |
| `ModuleNotFoundError` | wrong virtualenv, missing dependency, or wrong project package name |
| `permission denied` | service user cannot read code, env file, socket, static, or media path |
| `could not connect to server` | PostgreSQL is down, private address is wrong, or credentials are wrong |
| `Address already in use` | another process is already bound to that port/socket |

The log is evidence. Preserve it while you debug.

---

<!-- Source: deployment-stacks/gunicorn.md -->

# 14. Gunicorn: the WSGI application server

Gunicorn imports the Django WSGI application and manages Python worker processes. It is the bridge between your reverse proxy and Django.

## Why Gunicorn exists

`runserver` is a development tool. Gunicorn is a production WSGI process manager that accepts HTTP from a trusted local proxy and routes work into Django workers.

## Minimal systemd service

```ini
# /etc/systemd/system/<APP_NAME>.service
[Unit]
Description=<APP_NAME> Django application via Gunicorn
After=network.target postgresql.service
Wants=postgresql.service

[Service]
Type=simple
User=<APP_USER>
Group=<APP_USER>
WorkingDirectory=/srv/<APP_NAME>/app
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
ExecStart=/srv/<APP_NAME>/venv/bin/gunicorn \
  --workers 3 \
  --bind 127.0.0.1:8000 \
  --access-logfile - \
  --error-logfile - \
  <PROJECT_PACKAGE>.wsgi:application
Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

## Explain each important directive

| Directive | Why it exists |
|---|---|
| `User` / `Group` | runs Python with limited privileges |
| `WorkingDirectory` | lets Django resolve project-relative paths predictably |
| `EnvironmentFile` | provides production variables without committing them to Git |
| `ExecStart` | absolute command systemd executes |
| `--workers 3` | three synchronous workers; tune from measurement, not folklore |
| `--bind 127.0.0.1:8000` | local-only port; reverse proxy is the public entry point |
| `--access-logfile -` / `--error-logfile -` | emits logs into `journalctl` |
| `Restart=on-failure` | restarts a crash, but preserves evidence in logs |

## Worker count

A common starting heuristic is a small number of workers such as 2–3 for a small VPS. A popular formula such as `2 × CPU + 1` is only a heuristic. Each Python worker consumes memory; too many workers can make a small VPS slower or unstable. Start conservatively, observe memory, latency, and worker timeouts, then tune.

## Bind choices

| Binding | Good for | Trade-off |
|---|---|---|
| `127.0.0.1:8000` | easiest to understand; works with all proxies | reserves a local TCP port |
| Unix socket | same-host proxy/app communication | requires socket permissions and proxy-specific syntax |
| `0.0.0.0:8000` | almost never needed | exposes app server unless firewall/proxy constraints are perfect |

Start with loopback TCP. Move to a Unix socket only when you understand and benefit from it.

## Verify Gunicorn before configuring a proxy

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now <APP_NAME>
sudo systemctl status <APP_NAME>
curl -I http://127.0.0.1:8000/
```

A `400 DisallowedHost` from this direct test can be expected if the Host header is not allowed; use a permitted Host or focus on service logs. Do not open port 8000 to the internet merely to test it.

## What happens when Gunicorn starts

When systemd runs the `ExecStart` command, Gunicorn does roughly this:

1. starts a master process;
2. imports `<PROJECT_PACKAGE>.wsgi:application`;
3. creates worker processes;
4. listens on `127.0.0.1:8000`;
5. waits for the reverse proxy to send HTTP requests;
6. passes each request into Django;
7. writes access/error logs to stdout/stderr, which systemd captures.

If import fails, workers never become healthy. That usually means a Python error, missing dependency, bad environment variable, or wrong project package name.

## Understanding `<PROJECT_PACKAGE>.wsgi:application`

If your Django project was created with:

```bash
django-admin startproject config .
```

then your WSGI object is usually:

```text
config.wsgi:application
```

The part before the colon is a Python module path. The part after the colon is the variable inside that module. Gunicorn imports it just like Python code would. If your project package is named `mysite`, use `mysite.wsgi:application` instead.

## Why Gunicorn should not be public

Gunicorn is good at running Python workers. It is not meant to be your full public internet edge. The reverse proxy is better at TLS, slow-client buffering, static files, request size limits, compression, and mature HTTP behavior.

That is why this guide binds Gunicorn to loopback:

```text
127.0.0.1:8000
```

Only processes on the same server can reach that address. The public internet reaches Nginx/Apache/Caddy on ports 80 and 443, and the proxy reaches Gunicorn privately.

## Common Gunicorn failure modes

| Symptom | Likely cause | First place to look |
|---|---|---|
| service fails immediately | wrong module path, missing dependency, missing env var | `journalctl -u <APP_NAME>` |
| `Address already in use` | another service is bound to the same port | `sudo ss -ltnp` |
| requests hang | worker exhaustion, slow DB/API call, deadlock | Gunicorn logs, Django logs, DB activity |
| frequent worker timeouts | slow view, slow query, external API wait, too few workers | app traces and request logs |
| high memory usage | too many workers, memory leak, large in-process data | `systemctl status`, metrics, process list |

Do not tune Gunicorn by copying random worker counts. First identify whether the bottleneck is CPU, memory, database, network, or application code.

## Development versus production Gunicorn

During development, Django's `runserver` reloads code and prints friendly tracebacks. Gunicorn does not exist to make local development nicer; it exists to run stable worker processes in production. In production:

- code changes require a restart or reload;
- logs go to systemd or a configured log path;
- secrets come from the service environment;
- the process runs as a limited user;
- the bind address is private;
- a reverse proxy handles public HTTP/TLS.

That difference is intentional. Production values repeatability and control over convenience.

---

<!-- Source: deployment-stacks/nginx-gunicorn-postgresql.md -->

# 15. Nginx + Gunicorn + PostgreSQL

This is the recommended reference stack for a first conventional Django VPS deployment.

```text
Internet → Nginx :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Why this stack

Nginx is excellent at public HTTP/TLS, redirects, static file delivery, buffering slow clients, and reverse proxying. Gunicorn focuses on Python workers. PostgreSQL stores application data. Each component has a narrow, understandable job.

## Install Nginx and Certbot

```bash
sudo apt install -y nginx certbot python3-certbot-nginx
sudo systemctl enable --now nginx
```

## HTTP configuration before certificate issuance

```nginx
# /etc/nginx/sites-available/<APP_NAME>
server {
    listen 80;
    listen [::]:80;
    server_name <DOMAIN> <WWW_DOMAIN>;

    location /static/ {
        alias /srv/<APP_NAME>/staticfiles/;
    }

    location /media/ {
        alias /srv/<APP_NAME>/media/;
    }

    location / {
        proxy_pass http://127.0.0.1:8000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and test:

```bash
sudo ln -s /etc/nginx/sites-available/<APP_NAME> /etc/nginx/sites-enabled/<APP_NAME>
sudo nginx -t
sudo systemctl reload nginx
```

## Explain the configuration

| Directive | Meaning |
|---|---|
| `listen 80` | accepts HTTP for certificate validation/initial traffic |
| `server_name` | chooses this server block for matching hostnames |
| `alias` | maps web paths to filesystem directories; trailing slash matters |
| `proxy_pass` | forwards dynamic requests to Gunicorn locally |
| `Host` | preserves the client hostname so Django can apply host checks |
| `X-Forwarded-For` | records original client address chain |
| `X-Forwarded-Proto` | tells Django whether the browser used HTTPS |

## Obtain TLS certificate

Once DNS resolves to this server and port 80 is reachable:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

Certbot can modify the Nginx configuration to add certificate paths and an HTTP-to-HTTPS redirect. Read the resulting file rather than treating it as magic.

## Final Nginx behavior

After TLS, your HTTP server block should redirect all requests to HTTPS. Your HTTPS server block should continue to serve static/media and proxy dynamic paths.

## Verification

```bash
sudo nginx -t
sudo systemctl status nginx
sudo systemctl status <APP_NAME>
curl -I http://<DOMAIN>
curl -I https://<DOMAIN>
curl -fsS https://<DOMAIN>/healthz/
```

## Common Nginx/Gunicorn problems

- `502 Bad Gateway`: Gunicorn stopped, wrong port, wrong `proxy_pass`, or application crash.
- static `404`: wrong `alias` path or missing `collectstatic`.
- `403`: Nginx lacks directory traversal/read permission, or an app-level CSRF rule is failing.
- redirect loop: `X-Forwarded-Proto` and Django `SECURE_PROXY_SSL_HEADER` disagree.

## Walk through the Nginx server block slowly

```nginx
server {
```

A `server` block is one virtual host. Nginx can host multiple sites on one machine; it chooses the block using the request port and hostname.

```nginx
listen 80;
listen [::]:80;
```

These lines accept HTTP on IPv4 and IPv6. Port 80 is also used by common Let's Encrypt validation.

```nginx
server_name <DOMAIN> <WWW_DOMAIN>;
```

This says which hostnames belong to this site. If the browser requests `example.com`, Nginx can match that name to the correct block.

```nginx
location /static/ {
    alias /srv/<APP_NAME>/staticfiles/;
}
```

Requests beginning with `/static/` are served directly from the `staticfiles` directory. Django does not handle these files in production. The trailing slash on `alias` matters because Nginx joins the remaining request path to that directory.

```nginx
location /media/ {
    alias /srv/<APP_NAME>/media/;
}
```

This serves user-uploaded files when you use local media storage. If you use S3-compatible object storage, this block may disappear because media is served by object storage/CDN instead.

```nginx
location / {
    proxy_pass http://127.0.0.1:8000;
```

`location /` catches dynamic application requests. `proxy_pass` sends them to Gunicorn on the private loopback port.

```nginx
proxy_set_header Host $host;
```

This preserves the original hostname. Django needs it for `ALLOWED_HOSTS`, URL generation, CSRF checks, and redirects.

```nginx
proxy_set_header X-Real-IP $remote_addr;
proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
```

These pass client IP information to the app. If you are behind another proxy or CDN, the chain can contain more than one IP. Do not blindly trust it for security decisions unless your proxy chain is controlled.

```nginx
proxy_set_header X-Forwarded-Proto $scheme;
```

This tells Django whether the browser used HTTP or HTTPS at the public edge. Django can use it with `SECURE_PROXY_SSL_HEADER` when Gunicorn is private.

## How to debug the stack layer by layer

Use this order:

1. `dig +short <DOMAIN>` confirms DNS points to the server.
2. `sudo ufw status numbered` confirms ports 80 and 443 are open.
3. `sudo nginx -t` confirms Nginx config syntax.
4. `sudo systemctl status nginx` confirms Nginx is running.
5. `sudo systemctl status <APP_NAME>` confirms Gunicorn is running.
6. `curl -I http://127.0.0.1:8000/` tests Gunicorn from the server.
7. `curl -I http://<DOMAIN>/` tests the public HTTP path.
8. `curl -I https://<DOMAIN>/` tests the public HTTPS path after TLS.

This order prevents guessing. A 502 is different from DNS failure, and both are different from a Django 500.

## What Nginx is responsible for in this stack

Nginx is the public HTTP edge. It should handle:

- listening on ports 80 and 443;
- redirecting HTTP to HTTPS after certificates work;
- serving static files from `STATIC_ROOT`;
- serving public media if local media is the chosen design;
- forwarding dynamic requests to Gunicorn;
- setting proxy headers for Django;
- writing access/error logs;
- buffering slow clients so Python workers are not tied up unnecessarily.

Nginx should not run Django code, connect directly to PostgreSQL, or store application secrets.

## Request path with failure points

```text
browser
  -> DNS resolves domain
  -> provider firewall allows 80/443
  -> UFW allows 80/443
  -> Nginx chooses server block by server_name
  -> /static/ and /media/ may be served from disk
  -> other paths proxy to 127.0.0.1:8000
  -> Gunicorn sends request into Django
  -> Django talks to PostgreSQL
```

When something breaks, locate the failed arrow. If DNS is wrong, Django settings cannot fix it. If Gunicorn is stopped, changing Nginx `server_name` cannot fix it.

## Static files in this stack

`collectstatic` copies static files into `STATIC_ROOT`. Nginx then serves that directory. The flow is:

```text
Django app static sources
  -> manage.py collectstatic
  -> /srv/<APP_NAME>/staticfiles
  -> Nginx alias /static/
  -> browser downloads CSS/JS/images
```

If the admin has no CSS, check `collectstatic`, `STATIC_ROOT`, the Nginx `alias`, and filesystem permissions.

---

<!-- Source: deployment-stacks/apache-gunicorn-postgresql.md -->

# 16. Apache + Gunicorn + PostgreSQL

Use this stack when Apache is already your web-server standard or you prefer its virtual-host/module ecosystem.

```text
Internet → Apache :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Install modules

```bash
sudo apt install -y apache2 certbot python3-certbot-apache
sudo a2enmod proxy proxy_http headers ssl rewrite
sudo systemctl enable --now apache2
```

## HTTP virtual host before TLS

```apache
# /etc/apache2/sites-available/<APP_NAME>.conf
<VirtualHost *:80>
    ServerName <DOMAIN>
    ServerAlias <WWW_DOMAIN>

    Alias /static/ /srv/<APP_NAME>/staticfiles/
    <Directory /srv/<APP_NAME>/staticfiles/>
        Require all granted
    </Directory>

    Alias /media/ /srv/<APP_NAME>/media/
    <Directory /srv/<APP_NAME>/media/>
        Require all granted
    </Directory>

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "http"
    ProxyPass /static/ !
    ProxyPass /media/ !
    ProxyPass / http://127.0.0.1:8000/
    ProxyPassReverse / http://127.0.0.1:8000/

    ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
    CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
</VirtualHost>
```

Enable and test:

```bash
sudo a2ensite <APP_NAME>.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

## TLS

```bash
sudo certbot --apache -d <DOMAIN> -d <WWW_DOMAIN>
```

After Certbot creates/enables the TLS virtual host, ensure the HTTPS vhost sends:

```apache
RequestHeader set X-Forwarded-Proto "https"
```

and preserves `ProxyPreserveHost On`. Django can then be configured with `SECURE_PROXY_SSL_HEADER` when appropriate.

## Why Apache + Gunicorn instead of mod_wsgi?

This keeps Python process management separate from the web server. Gunicorn is easy to run under systemd, restart, and inspect through its own journal. Choose mod_wsgi when you specifically want Apache to host WSGI directly and understand its Python/virtualenv compatibility requirements.

## Verification

```bash
sudo apache2ctl configtest
sudo systemctl status apache2
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo tail -n 100 /var/log/apache2/<APP_NAME>-error.log
```

## Walk through the Apache virtual host slowly

```apache
<VirtualHost *:80>
```

This begins an Apache virtual host that listens for HTTP traffic on port 80. The `*` means Apache can accept the request on any local IP address assigned to the server.

```apache
ServerName <DOMAIN>
ServerAlias <WWW_DOMAIN>
```

`ServerName` is the primary hostname for this site. `ServerAlias` lists additional names that should use the same configuration. These should match DNS records, certificate names, and Django `ALLOWED_HOSTS`.

```apache
Alias /static/ /srv/<APP_NAME>/staticfiles/
<Directory /srv/<APP_NAME>/staticfiles/>
    Require all granted
</Directory>
```

`Alias` maps the browser path `/static/` to a real filesystem directory. The matching `<Directory>` block gives Apache permission to serve files from that directory. Without `Require all granted`, Apache may know where the files are but still refuse access.

```apache
Alias /media/ /srv/<APP_NAME>/media/
```

This serves local user uploads. If media files are private, sensitive, or stored in object storage, do not expose this path blindly. Public media and private media need different designs.

```apache
ProxyPreserveHost On
```

This tells Apache to pass the original `Host` header to Gunicorn. Django needs the real host for `ALLOWED_HOSTS`, redirects, CSRF behavior, and absolute URL generation.

```apache
RequestHeader set X-Forwarded-Proto "http"
```

This sets a header that tells Django what protocol the browser used at the public edge. In the HTTP vhost it is `http`; in the HTTPS vhost it should be `https`.

```apache
ProxyPass /static/ !
ProxyPass /media/ !
```

The exclamation mark means "do not proxy this path." Apache should serve static and media files itself instead of sending them to Gunicorn.

```apache
ProxyPass / http://127.0.0.1:8000/
ProxyPassReverse / http://127.0.0.1:8000/
```

`ProxyPass` forwards dynamic requests to Gunicorn on the private loopback port. `ProxyPassReverse` rewrites certain upstream response headers, such as redirects, so the client sees the public site address rather than the private backend address.

```apache
ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
```

These create per-site logs. Error logs help debug Apache/proxy/static issues. Access logs show request paths, status codes, client IPs, and timing depending on the log format.

## Explain the Apache commands

```bash
sudo a2enmod proxy proxy_http headers ssl rewrite
```

`a2enmod` enables Apache modules. `proxy` and `proxy_http` support reverse proxying to Gunicorn. `headers` lets Apache set forwarded headers. `ssl` supports HTTPS. `rewrite` is commonly used by Certbot or redirect rules.

```bash
sudo a2ensite <APP_NAME>.conf
```

This enables the site by creating the right symlink from `sites-available` to `sites-enabled`.

```bash
sudo apache2ctl configtest
```

This checks Apache syntax before reload. Run it before every Apache reload.

```bash
sudo systemctl reload apache2
```

Reload asks Apache to reread configuration without a full stop/start when possible. If config syntax is broken, do not reload until it is fixed.

## What Apache is responsible for in this stack

Apache plays the same public-edge role that Nginx plays in the reference stack. It should handle HTTP/TLS, static files, public media if applicable, proxying to Gunicorn, request headers, and access/error logs.

Gunicorn still owns Python worker management. PostgreSQL still owns durable relational data. Keeping those responsibilities separate makes debugging easier.

## Apache request path

```text
browser
  -> Apache virtual host selected by ServerName/ServerAlias
  -> Alias serves /static/ or /media/ from disk
  -> ProxyPass sends dynamic requests to Gunicorn
  -> Gunicorn runs Django WSGI app
  -> Django queries PostgreSQL
```

If Apache returns a 404 for a static file, inspect Apache `Alias` and filesystem paths. If Apache returns 502/503, inspect the Gunicorn service. If Django returns 500, inspect the app journal and Django traceback.

## Apache module mental model

Apache features are often modules. The config only works when the required modules are enabled:

| Module | Why this stack needs it |
|---|---|
| `proxy` | base proxy capability |
| `proxy_http` | proxy HTTP requests to Gunicorn |
| `headers` | set `X-Forwarded-Proto` and similar headers |
| `ssl` | serve HTTPS |
| `rewrite` | redirects and Certbot-managed rules |

If Apache says a directive is invalid, the module that provides that directive may not be enabled.

---

<!-- Source: deployment-stacks/apache-mod-wsgi.md -->

# 17. Apache + mod_wsgi

`mod_wsgi` is an Apache module that hosts Python WSGI applications. This removes Gunicorn from the architecture:

```text
Internet → Apache + mod_wsgi → Django → PostgreSQL
```

## When it is a good choice

- Apache is already mandatory/standard in the environment.
- Your team has mod_wsgi operational experience.
- You prefer one service family rather than proxying to Gunicorn.

## What makes it harder

`mod_wsgi` is compiled against a Python installation. The Python version and virtual environment must be compatible. This is why Gunicorn is often the lower-friction first choice for a standalone Django VPS.

## Install

```bash
sudo apt install -y apache2 libapache2-mod-wsgi-py3
sudo a2enmod wsgi ssl headers
```

## Daemon-mode configuration

Use daemon mode so Django runs in its own managed Apache daemon group rather than inside generic Apache worker processes.

```apache
# /etc/apache2/sites-available/<APP_NAME>.conf
<VirtualHost *:80>
    ServerName <DOMAIN>

    Alias /static/ /srv/<APP_NAME>/staticfiles/
    <Directory /srv/<APP_NAME>/staticfiles/>
        Require all granted
    </Directory>

    WSGIDaemonProcess <APP_NAME> \
        python-home=/srv/<APP_NAME>/venv \
        python-path=/srv/<APP_NAME>/app \
        processes=2 threads=15
    WSGIProcessGroup <APP_NAME>
    WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py

    <Directory /srv/<APP_NAME>/app/<PROJECT_PACKAGE>>
        <Files wsgi.py>
            Require all granted
        </Files>
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/<APP_NAME>-error.log
    CustomLog ${APACHE_LOG_DIR}/<APP_NAME>-access.log combined
</VirtualHost>
```

## Important notes

- Confirm the installed `mod_wsgi` matches your Python major/minor version.
- Make code readable/traversable by the Apache/mod_wsgi daemon user.
- Static files should still be served by Apache, not Django.
- Use `collectstatic` and private environment variables exactly as you would with Gunicorn.
- Use Certbot and the same UFW model: only 22/80/443 public.

## Select this on purpose

Do not treat mod_wsgi as automatically “more native” or Gunicorn as automatically “more modern.” Both are valid WSGI approaches. Pick the one your operational model can support confidently.

## Walk through the mod_wsgi directives

```apache
WSGIDaemonProcess <APP_NAME> \
    python-home=/srv/<APP_NAME>/venv \
    python-path=/srv/<APP_NAME>/app \
    processes=2 threads=15
```

This creates a named daemon process group for the Django app. `python-home` points to the virtual environment. `python-path` points to the Django project code. `processes=2` starts two daemon processes. `threads=15` allows each process to handle multiple threaded requests.

More processes and threads are not automatically better. Each process uses memory, and threaded code must be safe with shared in-process state. Start modestly and measure.

```apache
WSGIProcessGroup <APP_NAME>
```

This tells Apache that requests for this virtual host should run in the daemon group created above, not in the generic Apache process pool.

```apache
WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py
```

This maps the URL root `/` to Django's WSGI entrypoint file. Apache imports that file through mod_wsgi and calls the WSGI application object inside it.

```apache
<Directory /srv/<APP_NAME>/app/<PROJECT_PACKAGE>>
    <Files wsgi.py>
        Require all granted
    </Files>
</Directory>
```

Apache needs explicit permission to access the WSGI file. This does not mean every project file becomes public; it allows Apache/mod_wsgi to load the entrypoint.

## How environment variables work with mod_wsgi

A Gunicorn systemd service usually reads `EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env`. With mod_wsgi, Apache is hosting Python, so environment handling is different. Common options are:

- set variables in Apache config with `SetEnv`, then load them in `wsgi.py` when appropriate;
- use a small environment-loading package in Django settings;
- keep secrets in a root-owned file and load it carefully before Django settings need them.

Do not assume the shell environment you see over SSH is visible to Apache. Service managers start processes with their own environment.

## Debugging mod_wsgi startup

If the app fails under mod_wsgi but works locally, check:

1. Apache error log for Python traceback;
2. Python version used by mod_wsgi;
3. virtualenv path in `python-home`;
4. project path in `python-path`;
5. file permissions for Apache/mod_wsgi user;
6. missing environment variables;
7. imports that depend on the current working directory.

mod_wsgi is reliable when configured correctly, but the Python/runtime coupling is stricter than the Gunicorn systemd model.

## Full mod_wsgi request lifecycle

```text
browser
  -> Apache virtual host
  -> Apache serves /static/ directly when matched
  -> mod_wsgi daemon process imports wsgi.py
  -> Django handles dynamic request
  -> Django queries PostgreSQL
  -> response returns through Apache
```

There is no Gunicorn service in this stack. That means there is also no Gunicorn journal. Python errors usually appear in Apache's error log.

## What `daemon mode` means

mod_wsgi can run apps in embedded mode or daemon mode. Daemon mode creates a separate process group for the application. This is preferred for Django because it gives you clearer process isolation, easier virtualenv configuration, and more predictable restarts than mixing the app into generic Apache workers.

## mod_wsgi environment example

One common pattern is to adjust `wsgi.py` so it loads environment before Django settings are imported. The exact method depends on your secret-management choice, but the order matters:

```python
import os

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "<PROJECT_PACKAGE>.settings")

from django.core.wsgi import get_wsgi_application
application = get_wsgi_application()
```

By the time `get_wsgi_application()` runs, Django settings must be able to read all required variables. If `SECRET_KEY` or database variables are missing, startup fails.

## When mod_wsgi is the wrong choice

Avoid mod_wsgi when:

- you do not control the Python/mod_wsgi version compatibility;
- your team is more comfortable with systemd service logs than Apache-hosted Python logs;
- you need ASGI/WebSockets;
- you want the simplest beginner path on a clean VPS.

It is a valid production stack, but it is less forgiving for beginners than Apache/Nginx proxying to Gunicorn.

---

<!-- Source: deployment-stacks/caddy-gunicorn.md -->

# 18. Caddy + Gunicorn

Caddy is a web server and reverse proxy with automatic HTTPS as a central feature.

```text
Internet → Caddy :80/:443 → Gunicorn 127.0.0.1:8000 → Django → PostgreSQL
```

## Why choose Caddy

- concise configuration,
- automatic certificate provisioning and renewal for valid public hostnames,
- automatic HTTP-to-HTTPS redirect behavior in normal cases,
- useful defaults for a small server.

Caddy does not replace Django security settings, database backups, UFW, systemd, or testing.

## Example Caddyfile

```caddyfile
# /etc/caddy/Caddyfile
<DOMAIN>, <WWW_DOMAIN> {
    encode zstd gzip

    handle_path /static/* {
        root * /srv/<APP_NAME>/staticfiles
        file_server
    }

    handle_path /media/* {
        root * /srv/<APP_NAME>/media
        file_server
    }

    reverse_proxy 127.0.0.1:8000 {
        header_up Host {host}
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Proto {scheme}
    }
}
```

## Notes

- Caddy must be able to bind ports 80 and 443 and the public DNS record must point to the server.
- `handle_path` strips the matching prefix; use it only when the filesystem root is set for the stripped path. Test static URLs carefully.
- Configure Django proxy awareness only if the proxy sends the required forwarded-proto header.
- Use `caddy validate --config /etc/caddy/Caddyfile` before reloads.

## When not to choose Caddy

Do not pick Caddy only because it has fewer lines of config if your team has established Apache/Nginx processes that are better understood and maintained. Operational familiarity is a real technical advantage.

## Walk through the Caddyfile

```caddyfile
<DOMAIN>, <WWW_DOMAIN> {
```

This site block handles the listed hostnames. Caddy will try to obtain and renew HTTPS certificates for valid public names automatically.

```caddyfile
encode zstd gzip
```

This enables response compression when useful. Compression reduces bandwidth for text responses such as HTML, CSS, and JavaScript.

```caddyfile
handle_path /static/* {
    root * /srv/<APP_NAME>/staticfiles
    file_server
}
```

`handle_path` matches `/static/*` and strips the matched prefix before looking on disk. `root` selects the filesystem directory. `file_server` tells Caddy to serve files directly.

```caddyfile
handle_path /media/* {
    root * /srv/<APP_NAME>/media
    file_server
}
```

This serves local media files. Use this only when local public media is the intended design.

```caddyfile
reverse_proxy 127.0.0.1:8000 {
```

All other requests go to Gunicorn on the private local port. Caddy remains the public edge; Gunicorn remains private.

```caddyfile
header_up Host {host}
header_up X-Real-IP {remote_host}
header_up X-Forwarded-For {remote_host}
header_up X-Forwarded-Proto {scheme}
```

These pass request context to Django. `{host}` is the browser-requested hostname. `{scheme}` is usually `https` after Caddy terminates TLS.

## Caddy operational commands

```bash
sudo caddy validate --config /etc/caddy/Caddyfile
```

Checks config syntax before reload.

```bash
sudo systemctl reload caddy
```

Reloads Caddy after a valid config change.

```bash
sudo journalctl -u caddy -n 100 --no-pager
```

Shows Caddy logs, including certificate and proxy errors.

Caddy is concise, but you still need to understand the path behavior. Most Caddy static-file mistakes come from confusing `handle`, `handle_path`, `root`, and the URL prefix that remains after matching.

## Caddy request path

```text
browser
  -> Caddy site block selected by hostname
  -> automatic TLS certificate is used when available
  -> /static/* and /media/* may be served from disk
  -> reverse_proxy sends dynamic requests to Gunicorn
  -> Gunicorn runs Django
  -> Django talks to PostgreSQL
```

Caddy hides some TLS complexity, but the architecture is still the same: public proxy in front, private Python app server behind it.

## Automatic HTTPS does not remove verification

Caddy can issue and renew certificates automatically, but it still depends on:

- DNS pointing to the server;
- ports 80 and 443 being reachable;
- Caddy being able to write its certificate storage;
- no conflicting service already bound to 80/443;
- correct hostnames in the Caddyfile.

If certificate issuance fails, read `journalctl -u caddy`; do not assume Django is involved.

## `handle` versus `handle_path`

`handle_path /static/*` strips the matched `/static` prefix before file lookup. Plain `handle /static/*` does not strip it. This distinction is a common source of confusing 404s.

If your disk has:

```text
/srv/example/staticfiles/admin/css/base.css
```

and the browser requests:

```text
/static/admin/css/base.css
```

`handle_path /static/*` with `root * /srv/example/staticfiles` can find `admin/css/base.css` under that root. Test this before launch.

---

<!-- Source: deployment-stacks/asgi-and-websockets.md -->

# 19. ASGI: Uvicorn, Daphne, Hypercorn, and WebSockets

## Architecture

```text
Internet → Nginx/Apache/Caddy → ASGI server on localhost → Django ASGI app → PostgreSQL/Redis
```

Use this when the app requires WebSockets, live updates, async consumers, or other long-lived connections. Ordinary HTTP Django views can also run under ASGI.

## ASGI server comparison

| Server | Best known for | Notes |
|---|---|---|
| Uvicorn | widely used high-performance ASGI server | common choice for Django/Starlette/FastAPI |
| Daphne | Django Channels/WebSockets ecosystem | natural choice for Channels-oriented apps |
| Hypercorn | ASGI/WSGI and multiple protocol options | useful when its feature set fits your needs |

## Uvicorn systemd service example

```ini
# /etc/systemd/system/<APP_NAME>-asgi.service
[Unit]
Description=<APP_NAME> Django ASGI application via Uvicorn
After=network.target postgresql.service

[Service]
User=<APP_USER>
Group=<APP_USER>
WorkingDirectory=/srv/<APP_NAME>/app
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
ExecStart=/srv/<APP_NAME>/venv/bin/uvicorn \
  <PROJECT_PACKAGE>.asgi:application \
  --host 127.0.0.1 \
  --port 8001 \
  --proxy-headers
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## Nginx proxy settings for WebSockets

```nginx
location / {
    proxy_pass http://127.0.0.1:8001;
    proxy_http_version 1.1;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto $scheme;

    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
}
```

The `Upgrade` and `Connection` headers matter for WebSocket handshakes. They are not required for conventional WSGI HTTP proxying.

## Redis and background concerns

Real-time features may introduce Redis as a channel layer/cache/broker. Redis should also remain private, authenticated where applicable, and included in your backup/operational plan only when it stores durable or critical state.

## ASGI warning

Async code changes failure modes. Test disconnect behavior, long-lived client load, proxy timeouts, worker restarts, and background task interactions. Do not assume an ASGI migration is a one-line server substitution.

## Walk through the Uvicorn service

```ini
User=<APP_USER>
Group=<APP_USER>
```

Run the ASGI server as the limited app user, not root.

```ini
WorkingDirectory=/srv/<APP_NAME>/app
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
```

The working directory points to the code checkout. The environment file supplies Django settings, database credentials, and secrets.

```ini
ExecStart=/srv/<APP_NAME>/venv/bin/uvicorn \
  <PROJECT_PACKAGE>.asgi:application \
  --host 127.0.0.1 \
  --port 8001 \
  --proxy-headers
```

This starts Uvicorn from the virtual environment, imports Django's ASGI application, listens only on localhost, uses port 8001, and allows trusted proxy headers. Keep the ASGI server private behind the reverse proxy.

## Walk through the WebSocket proxy lines

```nginx
proxy_http_version 1.1;
```

WebSockets require HTTP/1.1 upgrade behavior. This line makes Nginx speak HTTP/1.1 to the upstream ASGI server.

```nginx
proxy_set_header Upgrade $http_upgrade;
proxy_set_header Connection "upgrade";
```

These pass the browser's WebSocket upgrade request through the proxy. Without them, a WebSocket endpoint may work locally but fail through Nginx.

## Timeouts and long-lived connections

WebSockets can stay open for minutes or hours. That changes capacity planning:

- each open connection consumes server resources;
- proxy read timeouts may close idle sockets;
- deploys must handle disconnect/reconnect behavior;
- load balancers may need sticky behavior depending on the app design;
- Redis/channel layers must stay private and monitored.

Do not switch to ASGI only because it sounds newer. Use it when your application behavior needs it.

## WSGI versus ASGI in plain language

WSGI is the traditional synchronous Python web interface. It is excellent for normal request/response Django pages.

ASGI supports both normal HTTP and long-lived async protocols such as WebSockets. Use ASGI when the application needs behavior like live chat, notifications, collaborative editing, streaming, or Django Channels consumers.

```text
WSGI: request comes in -> response goes out -> connection is done
ASGI: connection may stay open -> app may send/receive events over time
```

## Django ASGI entrypoint

A Django project usually has both files:

```text
<PROJECT_PACKAGE>/wsgi.py
<PROJECT_PACKAGE>/asgi.py
```

Gunicorn imports `wsgi.py`. Uvicorn/Daphne/Hypercorn import `asgi.py`. If you point Uvicorn at `.wsgi:application`, you are not using the intended ASGI entrypoint.

## Channels and Redis mental model

For WebSocket features across multiple workers or servers, Django Channels commonly uses Redis as a channel layer:

```text
browser WebSocket
  -> proxy
  -> ASGI worker
  -> channel layer Redis
  -> another worker/consumer may receive event
```

Redis should be private. If Redis is only used as a channel layer/cache, its backup requirements may differ from PostgreSQL. If you store critical durable data in Redis, your operational requirements change.

---

<!-- Source: deployment-stacks/docker-compose.md -->

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

---

<!-- Source: deployment-stacks/managed-platforms-and-kubernetes.md -->

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

---

<!-- Source: deployment-stacks/uwsgi-nginx.md -->

# 22. uWSGI + Nginx

uWSGI is another production WSGI application server. Django documents how to integrate it with Django, and Nginx can proxy to it using the uWSGI protocol.

```text
Internet → Nginx :80/:443 → uWSGI (private socket) → Django WSGI → PostgreSQL
```

## Why choose uWSGI

uWSGI is mature, powerful, and widely used. It provides many process-management, socket, and protocol options.

## Why it is not the default beginner choice

The number of uWSGI options and the distinction between the **uWSGI server** and the **uWSGI protocol** add cognitive load. Gunicorn is often easier to start, inspect, and operate for one Django app. Use uWSGI when your team or platform already standardizes on it or its features meet a known need.

## Example `uwsgi.ini`

```ini
[uwsgi]
chdir = /srv/<APP_NAME>/app
module = <PROJECT_PACKAGE>.wsgi:application
home = /srv/<APP_NAME>/venv
master = true
processes = 3
threads = 2
socket = 127.0.0.1:8002
vacuum = true
die-on-term = true
need-app = true
```

`die-on-term = true` makes uWSGI react correctly to systemd termination signals rather than attempting an unexpected reload behavior.

## systemd service outline

```ini
[Service]
User=<APP_USER>
Group=<APP_USER>
WorkingDirectory=/srv/<APP_NAME>/app
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
ExecStart=/srv/<APP_NAME>/venv/bin/uwsgi --ini /etc/<APP_NAME>/uwsgi.ini
Restart=on-failure
```

## Nginx location

```nginx
location / {
    include uwsgi_params;
    uwsgi_pass 127.0.0.1:8002;
}
```

Or use a Unix socket after understanding socket ownership and Nginx permissions.

## Operational rules

- Keep the uWSGI endpoint private: loopback or a private Unix socket.
- Put Nginx in front for TLS, static files, buffering, and access logging.
- Log through systemd/journald or a deliberate log path.
- Start from a simple config and add advanced options only when measured behavior calls for them.

Read the current uWSGI and Django integration documentation before using version-specific flags.

## Walk through `uwsgi.ini`

```ini
[uwsgi]
```

This begins the uWSGI configuration section.

```ini
chdir = /srv/<APP_NAME>/app
```

Change into the Django project directory before loading the app. This makes relative imports and paths more predictable.

```ini
module = <PROJECT_PACKAGE>.wsgi:application
```

This is the Django WSGI object uWSGI imports. It has the same meaning as Gunicorn's `<PROJECT_PACKAGE>.wsgi:application`.

```ini
home = /srv/<APP_NAME>/venv
```

This points uWSGI at the Python virtual environment for dependencies.

```ini
master = true
processes = 3
threads = 2
```

`master` enables uWSGI's master process. `processes` and `threads` control concurrency. Start modestly because each process and thread has memory and database-connection impact.

```ini
socket = 127.0.0.1:8002
```

uWSGI listens privately on the loopback interface. Nginx connects to this address using the uWSGI protocol.

```ini
vacuum = true
```

Clean up sockets and temporary files when uWSGI exits.

```ini
need-app = true
```

Fail startup if the Python app cannot be loaded. This is safer than running a broken server that only fails when requests arrive.

## Walk through the Nginx uWSGI location

```nginx
include uwsgi_params;
```

This loads standard parameters Nginx should pass to a uWSGI upstream, such as request method, path, query string, and server variables.

```nginx
uwsgi_pass 127.0.0.1:8002;
```

This forwards the request to the private uWSGI endpoint. Use `uwsgi_pass`, not `proxy_pass`, when speaking the uWSGI protocol.

The confusing part is naming: uWSGI is both a server and a protocol. Nginx `uwsgi_pass` means it is using the protocol; it does not mean Nginx is running your Python app itself.

## uWSGI request lifecycle

```text
browser
  -> Nginx receives HTTPS request
  -> Nginx serves static files directly when matched
  -> Nginx sends dynamic request with uwsgi protocol
  -> uWSGI imports Django WSGI application
  -> Django handles request
  -> PostgreSQL stores/loads data
```

The main difference from Gunicorn is the Nginx-to-app protocol and uWSGI's configuration model. Gunicorn usually receives HTTP from the proxy. uWSGI often receives the uWSGI protocol through `uwsgi_pass`.

## uWSGI operational cautions

uWSGI has many options because it is broad and mature. That flexibility is useful for experienced operators and confusing for beginners. Add options only when you know what behavior they change.

Common mistakes:

| Mistake | Result |
|---|---|
| using `proxy_pass` instead of `uwsgi_pass` | Nginx speaks the wrong protocol |
| wrong `module` path | app fails to load |
| wrong virtualenv in `home` | missing package/import errors |
| public uWSGI socket | app server exposed without HTTP edge protections |
| too many processes/threads | memory or DB connection pressure |

If you already know Gunicorn, choose uWSGI only for a specific operational reason.

---

<!-- Source: deployment-stacks/other-options.md -->

# 23. Other valid options and where they fit

The main stacks in this book cover the usual first choices. These tools are also valid in particular environments.

## Nginx Unit

Nginx Unit is an application server from the Nginx ecosystem that can run application processes with dynamic configuration. It can fit teams already using Unit, but it is a different product from Nginx itself. Learn its django-application/process model before choosing it as a “simpler Nginx.”

## Waitress

Waitress is a pure-Python WSGI server often valued for cross-platform simplicity. It can serve Django, but on Linux VPS deployments Gunicorn/uWSGI/mod_wsgi tend to have more common operational patterns. It is not normally the first choice for a high-concurrency Linux web stack.

## Traefik

Traefik is a reverse proxy/load balancer popular in Docker/Kubernetes environments because it discovers services dynamically through labels/providers.

**Use it when:** you have containerized multi-service routing and want dynamic configuration.

**Do not use it for:** one static Django service on a VPS when Nginx/Apache/Caddy would be simpler to understand.

## HAProxy

HAProxy is an excellent load balancer/proxy, especially in multi-instance/high-availability environments. It can sit in front of multiple Django application servers. For a single app on one host, it is usually unnecessary.

## CDN and object storage

A CDN can cache static content near users and absorb bandwidth. Object storage can hold media/uploads outside the app host.

**Benefits:** offloads static/media, improves global delivery, reduces single-disk risk.

**Responsibilities:** cache invalidation, signed/private media policy, origin access, upload configuration, storage backup/lifecycle, and correct proxy headers.

## Cloud load balancers

Cloud providers often offer managed HTTP/TLS load balancers. These can terminate TLS and distribute traffic to multiple app instances. Django must be configured carefully to understand forwarded HTTPS headers, and app instances must be stateless enough for multiple replicas.

## The selection rule

A technology is not better because it has more features. Prefer the smallest toolset that your team can correctly configure, monitor, patch, back up, and recover.

## Nginx Unit mental model

Nginx Unit is controlled through an API/config model rather than traditional Nginx `server` blocks. It can run application processes directly and update configuration dynamically. This can be attractive for platforms, but a beginner must learn Unit's listener, route, application, and process model. Do not confuse it with ordinary Nginx reverse proxy config.

## Waitress mental model

Waitress is a WSGI server written in Python. It is simple and cross-platform, which can be helpful on Windows or constrained environments. On a Linux VPS, the ecosystem around Gunicorn, uWSGI, and mod_wsgi is more common for Django production. If you choose Waitress, still put a reverse proxy in front for TLS/static files and keep it private.

## Traefik mental model

Traefik shines when services appear/disappear dynamically, especially in Docker and Kubernetes. Instead of manually writing every route, labels or providers tell Traefik how to route traffic.

That is useful when you have many containers. It is unnecessary overhead for a single Django service that can be described clearly in one Nginx, Apache, or Caddy config file.

## HAProxy mental model

HAProxy is excellent at load balancing and health checks:

```text
HAProxy
  -> Django app server A
  -> Django app server B
  -> Django app server C
```

It is usually placed in front of multiple app instances. For one app process on one server, it rarely adds value.

## CDN and object storage request path

Static/media architecture may evolve into:

```text
browser
  -> CDN
  -> object storage or origin server
```

For public static assets, this is straightforward. For user media, decide whether files are public, private, signed, expiring, cacheable, or subject to deletion rules. Private media needs more than "upload it to S3."

## Cloud load balancer request path

A managed load balancer often does this:

```text
browser HTTPS
  -> cloud load balancer terminates TLS
  -> private app instance HTTP
  -> Django
```

Django must understand the original scheme through trusted forwarded headers. App instances must be stateless enough that any instance can handle the next request.

## Final stack decision checklist

Before choosing any stack, answer:

```text
[ ] Who terminates HTTPS?
[ ] Who serves static files?
[ ] Who runs Python workers?
[ ] How does Django receive secrets?
[ ] Where does PostgreSQL run?
[ ] Where do media files live?
[ ] What restarts after reboot?
[ ] Where are logs?
[ ] How are backups created and restored?
[ ] How is a bad deploy rolled back?
```

If you cannot answer those questions, the stack is not ready for production yet.

---

<!-- Source: operations/tls-and-https.md -->

# 24. TLS, HTTPS, redirects, and HSTS

HTTPS is HTTP protected by TLS. TLS provides confidentiality, integrity, and server identity verification for browser-to-server traffic.

## Certificate prerequisites

Before Let’s Encrypt/Certbot can issue a normal public certificate:

- `<DOMAIN>` must resolve to the intended server,
- inbound port 80 must be reachable for common HTTP validation methods,
- the reverse proxy must have a matching virtual host/server block,
- no unrelated proxy/CDN behavior should block validation unless deliberately configured.

## Certbot patterns

For Nginx:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

For Apache:

```bash
sudo certbot --apache -d <DOMAIN> -d <WWW_DOMAIN>
```

The plugins can obtain certificates and modify configuration to enable TLS/redirects. Read the resulting config. Automation is not a substitute for understanding which vhost is serving which hostname.

## Verify renewal

```bash
sudo certbot renew --dry-run
systemctl list-timers | grep certbot
```

## HTTP-to-HTTPS redirect

Keep port 80 open even after HTTPS works so HTTP visitors can be redirected and ACME renewal can use HTTP validation. Your public application should use HTTPS.

## HSTS

HSTS tells browsers to remember that a domain should use HTTPS. It is powerful because client browsers enforce it after receiving the header.

A safe progression:

1. Verify HTTPS and redirect correctness.
2. Start with a short `SECURE_HSTS_SECONDS` value.
3. Verify all intended subdomains support HTTPS before enabling `includeSubDomains`.
4. Do not use preload options casually; recovery from a mistake can be slow.

## Proxy-aware Django security

When TLS terminates at the proxy, configure the proxy to set `X-Forwarded-Proto` and Django to trust it only when the app server is private. Then secure cookies and `SECURE_SSL_REDIRECT` behave consistently.

## What Certbot is doing

When you run:

```bash
sudo certbot --nginx -d <DOMAIN> -d <WWW_DOMAIN>
```

Certbot typically does four jobs:

1. asks Let's Encrypt for a certificate for the listed names;
2. proves control of those names, often through an HTTP challenge on port 80;
3. stores certificate files on the server;
4. updates the Nginx config if you use the Nginx plugin.

The `-d` flags list every hostname that should appear on the certificate. A certificate for `example.com` does not automatically cover `www.example.com` unless both names are included or a wildcard certificate is used.

## What can go wrong during certificate issuance

| Symptom | Likely cause |
|---|---|
| DNS validation fails | domain does not point to this server yet |
| connection timeout | provider firewall or UFW blocks port 80 |
| wrong site answers | Nginx/Apache server block does not match `server_name`/vhost |
| too many redirects | HTTP challenge is being redirected through a broken HTTPS path |
| CDN interference | proxy/CDN is not forwarding the challenge as expected |

Fix the path from the public internet to port 80 before rerunning repeatedly. Certificate authorities enforce rate limits.

## Why port 80 usually stays open

After HTTPS works, port 80 should not serve the application insecurely. It should redirect to HTTPS. Keeping it open is still useful because:

- users who type `example.com` often start on HTTP;
- ACME HTTP validation may need port 80;
- redirects give a clean path to HTTPS.

The important rule is not "close port 80." The important rule is "do not serve sensitive application traffic over plain HTTP."

---

<!-- Source: operations/firewall-ssh-and-host-security.md -->

# 25. Firewall, SSH, Fail2Ban, and host security

## UFW baseline

From an existing SSH session, first permit SSH, then web traffic, then enable UFW:

```bash
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status numbered
```

Keep the SSH session open and test a second login before declaring success.

Do not mix UFW with a separate hand-managed native nftables ruleset unless you fully understand ownership of the firewall configuration. Choose one clear source of truth.

## Provider firewall

Mirror the same inbound policy at the hosting provider: SSH, HTTP, HTTPS. The provider firewall is an outer boundary; UFW is a host boundary. One does not make the other useless.

## SSH hardening sequence

1. Create and test SSH key login.
2. Create a sudo-capable deploy user.
3. Test another SSH session as that user.
4. Disable root/password SSH login only after the key path is confirmed.
5. Retain console/provider recovery access.

Never apply a hardening recipe blindly while you have only one unverified way back into the server.

## Fail2Ban

Fail2Ban watches logs and temporarily bans repeated suspicious login failures. It is useful friction against basic brute force; it is not a replacement for keys and patched software.

```bash
sudo apt install -y fail2ban
```

Example SSH jail:

```ini
# /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

Then:

```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status sshd
```

## Patch management

Apply regular OS/package updates. Before large upgrades, have a backup and maintenance window. Security updates deserve priority, but update discipline includes verification—not just pressing upgrade and disappearing.

## Filesystem and process principles

- app processes run as non-root;
- production secrets are not world-readable;
- code is not edited casually on the server;
- database is private;
- reverse proxy is the only public application entry point;
- logs are reviewed, not ignored;
- backups are off-host;
- file uploads are treated as untrusted input and never executed as server-side code.

## Explain the UFW commands

```bash
sudo ufw allow OpenSSH
```

Allow the firewall profile for SSH before enabling UFW. This reduces the chance of locking yourself out.

```bash
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
```

Allow public HTTP and HTTPS. Port 80 is used for redirects and common certificate validation. Port 443 is normal HTTPS application traffic.

```bash
sudo ufw default deny incoming
```

Reject inbound connections unless a rule explicitly allows them.

```bash
sudo ufw default allow outgoing
```

Allow the server to initiate outbound connections, such as package downloads, API calls, DNS, and email provider connections.

```bash
sudo ufw enable
```

Turn on UFW. Do this only after SSH is allowed and you have a recovery path.

```bash
sudo ufw status numbered
```

Show active rules with numbers. Numbered output is useful when deleting a mistaken rule.

## Explain the Fail2Ban jail

```ini
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

`[sshd]` configures the SSH jail. `enabled = true` turns it on. `maxretry = 5` means five failures trigger a ban. `findtime = 10m` means those failures must occur within ten minutes. `bantime = 1h` means the ban lasts one hour.

Fail2Ban should reduce noisy brute-force attempts, but it is not your primary security model. SSH keys, patched software, least privilege, and restricted exposed ports matter more.

---

<!-- Source: operations/deployment-runbooks.md -->

# 26. Safe deployments, migrations, and rollbacks

A deployment should be a documented operation, not a memory test.

## Standard workflow

```text
local branch
→ tests/checks
→ commit
→ push to Git remote
→ inspect server state
→ pull exact code as deploy user
→ migrate if needed
→ collectstatic if needed
→ restart/reload service
→ smoke test
→ monitor logs
```

## Before deployment

Locally:

```bash
python manage.py test
python manage.py check
git status --short
git diff --check
git log -1 --oneline
```

On server:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git status --short --branch
git fetch origin
git log --oneline HEAD..origin/main
'
```

If the server working tree is dirty, understand why before pulling. Do not normalize `git reset --hard` as a deployment tool; it can erase uncommitted server state and hide process problems.

## Pull code safely

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
git pull --ff-only origin main
'
```

`--ff-only` prevents Git from creating an unexpected merge commit on the server. It stops when history cannot advance safely.

## Apply Django-level changes as the app user

```bash
sudo -u <APP_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
'
```

Run `migrate` when the release includes migrations; run `collectstatic` when static sources/settings changed. They are not magic rituals required for every Python edit.

## Reload the running app

For Gunicorn/Uvicorn under systemd:

```bash
sudo systemctl restart <APP_NAME>
```

For Apache/Nginx config edits:

```bash
sudo nginx -t && sudo systemctl reload nginx
# or
sudo apache2ctl configtest && sudo systemctl reload apache2
```

## Post-deploy verification

```bash
curl -fsS https://<DOMAIN>/healthz/
curl -I https://<DOMAIN>/
sudo systemctl --no-pager --full status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 50 --no-pager
```

Then manually test the critical user path that changed.

## Rollback philosophy

A clean rollback needs an earlier known-good Git commit/tag and an understanding of database compatibility. Code can often roll back quickly; schema/data changes may not. For risky migrations, plan a forward fix, a restore path, or a two-step compatible deployment rather than assuming `git checkout` solves every outage.

## Why the runbook uses `sudo -u ... bash -lc`

Many deployment commands must run as a specific Linux identity.

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git pull --ff-only origin main
'
```

Read it piece by piece:

| Piece | Meaning |
|---|---|
| `sudo -u <DEPLOY_USER>` | run the command as the deploy user, not root |
| `-H` | use that user's home directory environment |
| `bash -lc` | start a login-like shell and run the quoted commands |
| `cd /srv/<APP_NAME>/app` | move into the repository |
| `git pull --ff-only origin main` | update only if Git can move forward without a merge commit |

The same pattern appears with `<APP_USER>` for Django commands because migrations and checks should run with the same environment and permissions as the application service.

## Why `set -Eeuo pipefail` appears in scripts

```bash
set -Eeuo pipefail
```

This makes shell scripts fail earlier and more honestly:

| Option | Meaning |
|---|---|
| `-E` | preserve error traps in functions/subshells when used |
| `-e` | stop when a command fails |
| `-u` | fail when an unset variable is used |
| `-o pipefail` | fail a pipeline if any important command in it fails |

Without this, a script can keep going after a failed command and make the server state confusing.

## What each Django deploy command does

```bash
/srv/<APP_NAME>/venv/bin/python manage.py check
```

Runs Django's system checks. It catches many configuration mistakes before the app restarts.

```bash
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
```

Applies unapplied database migrations. `--noinput` prevents the command from waiting for keyboard input during an automated deployment.

```bash
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
```

Copies static assets from apps and project directories into `STATIC_ROOT`, where the web server can serve them.

## Beginner rollback examples

If the new code is bad but the database is still compatible, a simple rollback may be:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
git checkout <KNOWN_GOOD_COMMIT>
'
sudo systemctl restart <APP_NAME>
```

If migrations changed the database in a non-compatible way, code rollback may not be enough. You may need a forward fix, a reverse migration that was designed and tested, or a database restore. This is why risky migrations need a deployment plan before they reach production.

---

<!-- Source: operations/observability-and-incidents.md -->

# 27. Logging, monitoring, and incident response

## Logs are evidence

| Layer | Where to inspect |
|---|---|
| Gunicorn/Uvicorn systemd service | `journalctl -u <APP_NAME>` |
| Nginx | `/var/log/nginx/access.log`, `/var/log/nginx/error.log` or vhost logs |
| Apache | `/var/log/apache2/*access.log`, `*error.log` |
| PostgreSQL | distro/service log or `journalctl -u postgresql` |
| Django application errors | app-server journal/structured error tracking |

## Debug an HTTP 500

1. Reproduce the request once.
2. Follow the application service journal.
3. Read the traceback, not random old log entries.
4. Identify whether configuration, code, database, permissions, or an external dependency failed.
5. Fix locally and add a regression test when practical.
6. Deploy a narrow verified fix.

```bash
sudo journalctl -u <APP_NAME> -f
```

## Debug a 502

A `502 Bad Gateway` typically means the proxy reached its own process but cannot get a valid response from the upstream app server.

Check:

```bash
sudo systemctl status <APP_NAME>
curl -I http://127.0.0.1:8000/
sudo tail -n 100 /var/log/nginx/error.log
```

## Structured application logging

Plain tracebacks are useful, but production logs should also answer operational questions. Include request ID, release version, user/account identifier when safe, endpoint, status code, latency, and external dependency name. Never log passwords, tokens, session cookies, full credit-card data, or private payloads.

A practical flow is:

```text
request enters proxy
  -> request ID is assigned or preserved
  -> Django includes it in logs/errors
  -> error tracker links traceback to release
  -> deployment history shows what changed
```

## Metrics, alerts, and dashboards

Metrics are numeric signals over time. Alerts are rules that notify a human when a signal needs action. Dashboards are for investigation; they are not a substitute for alerts.

Useful starter alerts:

| Alert | Why it matters |
|---|---|
| HTTPS health check fails | users may not reach the app |
| repeated 5xx responses | app or dependency is failing |
| disk usage above threshold | logs/uploads/database can stop the server |
| certificate expires soon | HTTPS outage is predictable and preventable |
| backup job failed | recovery point objective is at risk |
| service restart loop | systemd is keeping a broken process alive |
| database connection exhaustion | requests may fail even while CPU looks fine |

## Tool choices

Common options:

| Tool | Typical use |
|---|---|
| Sentry | Django exception tracking, releases, performance samples |
| UptimeRobot/Better Stack/Pingdom | external uptime checks |
| Prometheus | metrics collection and alert rules |
| Grafana | metrics dashboards |
| Netdata | quick host-level visibility |
| systemd journal | first source for service logs on a VPS |

Use managed tools when they reduce operational load. Self-host monitoring only when you can also monitor, back up, upgrade, and secure the monitoring system.

## Monitoring layers

A useful small-app stack:

- external uptime monitor requests `/healthz/` over HTTPS;
- application error tracking reports uncaught exceptions with release/version metadata;
- system monitoring tracks CPU, memory, disk, service restarts, certificate expiry, backup success;
- database monitoring tracks connections, disk growth, slow queries when needed.

Monitoring does not prevent every failure. It reduces time-to-detection and gives you evidence.

## Incident response outline

```text
1. Detect: monitor/user/log alert.
2. Triage: scope, severity, last deploy, affected endpoint.
3. Contain: stop harmful action or roll back safe code.
4. Recover: restore service/data as needed.
5. Verify: health check + critical flow.
6. Learn: root cause, regression test, runbook/document update.
```

Avoid changing five unrelated variables while debugging. That destroys the evidence needed to understand the actual cause.

## Post-incident review

After recovery, write a short review while the evidence is fresh:

- impact window and affected users;
- triggering change or external event;
- detection source;
- what worked during response;
- what slowed response;
- permanent fixes, tests, alerts, or docs to add;
- owner and due date for each follow-up.

The point is not blame. The point is to make the next failure smaller, faster to detect, or easier to recover from.

---

<!-- Source: operations/backups-and-disaster-recovery.md -->

# 28. Backups, restore drills, and disaster recovery

A backup is only useful if it can be restored. A backup stored only on the same VPS is not sufficient for full server loss.

## What to back up

- PostgreSQL database dumps;
- user media/uploads if stored locally;
- protected environment files/secrets through a secure, documented recovery method;
- deployment config templates and service definitions (ideally Git, minus secrets);
- certificate material only if you have a reason; certificates can often be reissued, but account/config recovery matters.

## PostgreSQL custom-format dump

```bash
sudo -u postgres pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file=/var/backups/<APP_NAME>/postgresql/<APP_NAME>-$(date -u +%Y%m%dT%H%M%SZ).dump \
  <DB_NAME>
```

Verify the dump is readable:

```bash
sudo -u postgres pg_restore --list /var/backups/<APP_NAME>/postgresql/<FILE>.dump > /dev/null
```

## Restore drill into a separate database

Never first test a restore by overwriting production:

```bash
sudo -u postgres createdb <DB_NAME>_restore_test
sudo -u postgres pg_restore \
  --dbname=<DB_NAME>_restore_test \
  --no-owner \
  --no-privileges \
  /var/backups/<APP_NAME>/postgresql/<FILE>.dump
```

Inspect it, then remove the test database when done.

## Nightly systemd backup service

```ini
# /etc/systemd/system/<APP_NAME>-db-backup.service
[Unit]
Description=<APP_NAME> PostgreSQL backup
After=postgresql.service

[Service]
Type=oneshot
User=postgres
Group=postgres
UMask=0077
ExecStart=/usr/local/sbin/<APP_NAME>-db-backup
```

```ini
# /etc/systemd/system/<APP_NAME>-db-backup.timer
[Unit]
Description=Nightly <APP_NAME> PostgreSQL backup

[Timer]
OnCalendar=*-*-* 03:15:00 UTC
Persistent=true
Unit=<APP_NAME>-db-backup.service

[Install]
WantedBy=timers.target
```

`Persistent=true` means a missed run can be triggered after the machine comes back up.

## Off-server copy

Send encrypted backups to a different failure domain: object storage, another server, encrypted local storage, or a managed backup destination. Test the path and record retention policy.

## Disaster recovery questions

You should be able to answer:

- Where is the latest verified DB backup?
- Where are media files backed up?
- How do we restore a new server from Git + config + DB + media?
- Who can access the secrets needed to start the service?
- What is the acceptable data-loss window (RPO)?
- How quickly must service return (RTO)?

If there is no answer, the system has a recovery risk—not merely a documentation gap.

## Explain the `pg_dump` flags

```bash
sudo -u postgres pg_dump   --format=custom   --no-owner   --no-privileges   --file=/var/backups/<APP_NAME>/postgresql/<APP_NAME>-$(date -u +%Y%m%dT%H%M%SZ).dump   <DB_NAME>
```

Line by line:

| Part | Meaning |
|---|---|
| `sudo -u postgres` | run as the PostgreSQL operating-system admin user |
| `pg_dump` | create a logical backup of a database |
| `--format=custom` | use PostgreSQL's custom archive format, which works well with `pg_restore` |
| `--no-owner` | do not force restore ownership to the original database owner |
| `--no-privileges` | do not restore original grant statements automatically |
| `--file=...` | write the backup to this file |
| `$(date -u ...)` | put a UTC timestamp in the filename so backups do not overwrite each other |
| `<DB_NAME>` | the database to dump |

The command backs up database contents, not local media files and not environment files. Those need separate backup paths.

## What a restore drill proves

A restore drill proves more than "the file exists." It proves:

- the backup file is readable;
- the PostgreSQL version can restore it;
- the restore command is documented correctly;
- the database has enough disk space;
- operators know the steps before an emergency;
- the backup contains what the application actually needs.

Do restore drills into a separate test database. Never practice by overwriting production.

## RPO and RTO in plain language

RPO means "how much data can we afford to lose?" If backups run nightly, your worst normal loss may be close to 24 hours of database changes.

RTO means "how long can the service be down while we recover?" If rebuilding a VPS from scratch takes four hours, your real RTO is not five minutes.

These are business decisions, not only technical settings. A hobby blog and a paid SaaS product should not have the same recovery promises.

---

<!-- Source: operations/testing-ci-and-staging.md -->

# 29. Testing, CI, staging, and smoke tests

## Testing ladder

| Level | What it proves | Example |
|---|---|---|
| Unit test | isolated logic | slug generation, helper function |
| Model/view integration test | Django components work together | published post URL returns 200 |
| Browser/E2E test | critical user behavior in a real browser | signup → post → admin publish → public open |
| Staging test | production-like infrastructure behavior | proxy/TLS/static/migrations on separate app+DB |
| Production smoke test | deployed release answers basic requests | `/healthz/`, login page, one critical flow |

## Regression tests are operational memory

Every production bug that is inexpensive to encode should become a regression test. It turns a painful incident into protection against repeating it.

Examples for a blog app:

- publishing assigns `pub_date`;
- public post URLs use the intended local calendar date;
- drafts do not build a public detail URL;
- a normal user cannot edit another user’s post;
- CSRF-protected forms accept valid HTTPS-origin submissions.

## GitHub Actions example

```yaml
# .github/workflows/ci.yml
name: Django CI
on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python -m pip install --upgrade pip
      - run: pip install -r requirements.txt
      - run: python manage.py check
      - run: python manage.py test
```

Real projects may need a PostgreSQL service container and CI-only environment variables. Keep credentials test-only and do not copy production secrets into CI.

## Staging

A staging environment should be isolated:

```text
staging.example.com
separate app checkout/service
separate environment file
separate database
separate media/static location
safe test email recipient/backend
```

Do not point a feature branch at production data to “test for real.” Test migrations and POST actions against staging data. Production-like does not mean production-coupled.

## Browser tests

Playwright is a strong choice for real browser flows. Begin with one critical journey, not an enormous flaky suite:

```text
sign up → log in → create record → privileged publish/approve → public URL opens → dashboard works
```

## Production smoke tests

After each deploy, run a short, repeatable smoke check. It should be fast enough that you actually do it.

## Walk through the GitHub Actions workflow

```yaml
name: Django CI
```

This is the human-readable workflow name shown in GitHub.

```yaml
on:
  push:
  pull_request:
```

Run the workflow when code is pushed and when a pull request is opened or updated.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
```

A workflow contains jobs. This job is named `test` and runs on a fresh Ubuntu runner hosted by GitHub.

```yaml
- uses: actions/checkout@v4
```

Download your repository into the runner.

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
```

Install and select Python 3.12 for the job.

```yaml
- run: python -m pip install --upgrade pip
- run: pip install -r requirements.txt
```

Upgrade pip and install project dependencies.

```yaml
- run: python manage.py check
- run: python manage.py test
```

Run Django's configuration checks and test suite. If either command exits non-zero, the CI job fails.

## Adding PostgreSQL to CI

A real app often needs PostgreSQL in CI. That usually means adding a service container and test-only environment variables. Keep the CI database disposable. Never point CI at production PostgreSQL.

## CI is not deployment by itself

CI answers "does this revision pass automated checks?" Deployment answers "is this revision safely running on an environment?" A professional pipeline may combine them, but they are separate responsibilities.

---

<!-- Source: operations/scaling.md -->

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

---

<!-- Source: open-source/publishing-a-project.md -->

# 31. Publishing an open-source project

Public code is not automatically an open-source project. A usable public project needs a license, accurate setup instructions, contribution expectations, and a security path.

## Before making a repository public

- remove secrets from current files and Git history where necessary;
- confirm `.env`, private keys, database dumps, uploads, and local config are ignored;
- replace real values with `.env.example` placeholders;
- include a license;
- write a README that explains what the project does and how to run it;
- add a security reporting policy;
- document supported Python/Django/database versions;
- ensure screenshots/test content do not leak private data;
- run secret scanning or at minimum search tracked history/files.

## Secret checks

```bash
git grep -nEi 'secret|password|token|api[_-]?key|private[_-]?key' || true
git ls-files | grep -E '(^|/)(\.env|.*\.pem|.*\.key)$' || true
```

These are not complete secret scanners, but they create a useful review habit.

## README outline

```md
# Project Name

One-paragraph purpose statement.

## Features
## Screenshots / demo
## Quick start
## Configuration
## Local development
## Testing
## Production deployment
## Contributing
## Security
## License
```

## `.env.example`

A new contributor needs to know variable names without receiving real values:

```dotenv
DJANGO_SECRET_KEY=replace-me-for-local-development
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
POSTGRES_DB=myproject
POSTGRES_USER=myproject
POSTGRES_PASSWORD=replace-me
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

## Documentation-as-code

Keep technical documentation in Markdown next to the code. This makes setup instructions reviewable in pull requests and versioned alongside the code that they describe. Read the Docs can build and publish that Markdown as a versioned documentation site.

---

<!-- Source: open-source/license-governance-and-security.md -->

# 32. License, governance, contribution, and security policy

## Choose a license intentionally

A repository without a license is not a clear invitation for reuse. Common broad choices:

| License | Practical meaning |
|---|---|
| MIT | short permissive license; reuse with notice/disclaimer |
| Apache-2.0 | permissive with explicit patent terms |
| GPL-3.0 | copyleft; derivative distribution generally remains GPL-compatible |
| AGPL-3.0 | copyleft that also addresses network-service distribution |

This is not legal advice. Choose based on your goals, dependencies, organization, and jurisdiction. Do not copy a license you do not intend to honor.

## CONTRIBUTING.md

Tell contributors:

- supported setup path,
- branch/PR workflow,
- test commands,
- coding/style expectations,
- how to propose features and report bugs,
- how to handle migrations/docs/changelog changes.

## CODE_OF_CONDUCT.md

For community-facing projects, a code of conduct gives a clear behavior standard and a reporting route. Use a recognized template appropriate to your community, then name a real contact path.

## SECURITY.md

A security policy should contain:

- supported versions,
- private reporting contact/path,
- what information helps reproduce a vulnerability,
- what response timeline is realistic,
- a statement not to post exploitable details as public issues before coordination.

## Governance is operational clarity

Even a one-person project benefits from defined rules: who merges, how releases are cut, what branches are protected, what testing is required, and how breaking changes are communicated.

## Issue and pull request templates

Templates reduce incomplete reports. A useful bug report asks for:

- project version or commit;
- Django/Python/database versions;
- deployment stack if relevant;
- expected behavior;
- actual behavior;
- minimal reproduction;
- logs or traceback with secrets removed.

A useful pull request template asks for purpose, linked issue, test evidence, documentation updates, migration notes, and breaking-change impact. Keep templates short enough that contributors will actually complete them.

## Roadmap and support policy

A roadmap tells users what direction the project is taking. A support policy tells them what is maintained today. For documentation projects, state which Django versions, operating systems, and server stacks the guide actively tests or targets.

## Documentation contribution guide

Documentation has code-like quality rules. Ask contributors to keep commands copyable, explain placeholders, avoid real secrets/IPs, update both templates and explanatory chapters when needed, and cite official documentation for claims that change over time.

---

<!-- Source: open-source/releases-and-maintenance.md -->

# 33. Releases, SemVer, changelogs, and support

## Git commits, tags, and releases

- A **commit** is a source snapshot in history.
- A **branch** is a movable pointer to a line of work.
- A **tag** is a named pointer to a specific commit, useful for immutable release snapshots.
- A **release** is a human-facing publication around a tag: notes, downloads, known limitations, migration instructions.

Do not retarget a release tag after users may have consumed it unless correcting a serious mistake and communicating clearly. Create the next version instead.

## Semantic Versioning

`MAJOR.MINOR.PATCH` communicates compatibility intent:

```text
1.4.2
│ │ └─ compatible bug fix
│ └─── backward-compatible feature
└───── breaking change
```

Pre-release identifiers communicate instability/testing:

```text
0.2.0-beta.1
0.2.0-beta.2
0.2.0-rc.1
0.2.0
```

Use a new beta number for meaningful fixes after the previous beta. Do not call a release final merely because it has a tag; call it final when its support/compatibility promise is real.

## Changelog style

A useful release note includes:

```md
## Fixed
- Corrected timezone-aware public post URL generation.

## Added
- Added regression test for posts created near local midnight.

## Changed
- Documented production backup timer.

## Upgrade notes
- Run migrations: ...
- Run collectstatic: ...
```

## Support boundaries

State what is supported: Python/Django versions, database version, Linux target, deployment patterns, browser support, and security support window. Clear boundaries prevent users from assuming an untested configuration is guaranteed.

## Release checklist

Before publishing a release:

- run link and Markdown checks if available;
- verify examples against supported Django/Python versions where practical;
- confirm templates match the chapters;
- update changelog and upgrade notes;
- tag the release;
- publish human-readable release notes;
- announce breaking changes clearly.

For Read the Docs, run `mkdocs build --strict` and verify that navigation renders correctly and renamed pages do not leave broken links.

## Maintenance rhythm

Production guidance ages. Review the book on a schedule for Django LTS changes, Ubuntu LTS changes, PostgreSQL support windows, TLS/certificate client changes, package names, and deployment-tool behavior. Mark unverified patterns as unverified rather than letting readers assume they are current.

## Security maintenance

Security fixes should have a private intake path, a clear maintainer owner, a release note that avoids unnecessary exploit detail, and a supported-version statement. If a vulnerable command or configuration appears in the book, fix the chapter, template, reference checklist, and any all-in-one appendix that repeats it.

---

<!-- Source: reference/configuration-examples.md -->

# Configuration examples

This page links to the templates in `config-examples/`. They are intentionally generic and use placeholders.

| File | Use |
|---|---|
| [`config-examples/gunicorn.service`](../config-examples/gunicorn.service) | WSGI application systemd service |
| [`config-examples/uvicorn.service`](../config-examples/uvicorn.service) | ASGI application systemd service |
| [`config-examples/nginx-site.conf`](../config-examples/nginx-site.conf) | Nginx public proxy/static/TLS vhost shape |
| [`config-examples/apache-gunicorn.conf`](../config-examples/apache-gunicorn.conf) | Apache reverse proxy vhost shape |
| [`config-examples/apache-modwsgi.conf`](../config-examples/apache-modwsgi.conf) | Apache daemon-mode mod_wsgi vhost shape |
| [`config-examples/Caddyfile`](../config-examples/Caddyfile) | Caddy reverse proxy/static pattern |
| [`config-examples/django-production-settings.py`](../config-examples/django-production-settings.py) | production settings fragments |
| [`config-examples/app.env.example`](../config-examples/app.env.example) | environment variable names only |
| [`config-examples/db-backup.sh`](../config-examples/db-backup.sh) | database backup/verification pattern |
| [`config-examples/db-backup.service`](../config-examples/db-backup.service) | backup service |
| [`config-examples/db-backup.timer`](../config-examples/db-backup.timer) | nightly backup timer |
| [`config-examples/ci.yml`](../config-examples/ci.yml) | GitHub Actions basic test job |
| [`config-examples/docker-compose.yml`](../config-examples/docker-compose.yml) | conceptual Compose topology |

Read the accompanying stack/operations chapter before using a template. Config files are not interchangeable: proxy headers, locations, socket paths, users, and TLS ownership must match the selected stack.

## Learn the templates line by line

Use [Configuration walkthroughs](../reference/configuration-walkthroughs.md) when a config file is correct but still feels mysterious. It explains the important lines in the environment file, Django settings, Gunicorn service, Nginx site, Docker Compose file, and backup timers.

---

<!-- Source: reference/checklists.md -->

# Command checklists

## First public launch

```text
[ ] DNS resolves to the right server.
[ ] provider firewall allows only required ports.
[ ] UFW allows SSH/80/443 and denies other inbound traffic.
[ ] SSH key login works; root/password policy verified safely.
[ ] app runs as non-root service account.
[ ] PostgreSQL is private.
[ ] secrets are outside Git and permission-restricted.
[ ] DEBUG=False and ALLOWED_HOSTS are correct.
[ ] static files collected and served.
[ ] migrations applied.
[ ] HTTPS certificate works; renewal dry-run passes.
[ ] HTTP redirects to HTTPS.
[ ] service starts after reboot.
[ ] health endpoint and critical flow work.
[ ] backup exists, is verified, and copied off-host.
[ ] monitoring/error reporting is configured.
```

## Normal release

```text
[ ] local tests and Django checks pass.
[ ] migration reviewed.
[ ] Git working tree clean; commit/push complete.
[ ] server Git state inspected before pull.
[ ] code pulled with ff-only workflow.
[ ] migrate only if required.
[ ] collectstatic only if required.
[ ] app service restarted.
[ ] web-server config test/reload only if config changed.
[ ] health check and changed critical workflow tested.
[ ] logs monitored for new errors.
```

## Migration to another server

```text
[ ] target OS prepared; users/firewall/packages installed.
[ ] code cloned at intended release tag.
[ ] protected env file transferred securely.
[ ] database created and restore tested.
[ ] media copied/restored.
[ ] app service and proxy configured.
[ ] TLS certificate issued after DNS cutover or planned separately.
[ ] health/critical flow tested before switch.
[ ] DNS cutover completed and old server retained briefly for rollback.
[ ] backups/monitoring recreated on target.
```

---

<!-- Source: reference/troubleshooting.md -->

# Troubleshooting map

## Domain / connection

```bash
dig +short <DOMAIN>
curl -I http://<DOMAIN>
curl -Iv https://<DOMAIN>
sudo ufw status numbered
```

## Nginx

```bash
sudo nginx -t
sudo systemctl status nginx
sudo tail -n 100 /var/log/nginx/error.log
```

## Apache

```bash
sudo apache2ctl configtest
sudo systemctl status apache2
sudo tail -n 100 /var/log/apache2/error.log
```

## Application service

```bash
sudo systemctl status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 100 --no-pager
sudo journalctl -u <APP_NAME> -f
curl -I http://127.0.0.1:8000/
```

## Django configuration

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check --deploy
'
```

## PostgreSQL

```bash
sudo systemctl status postgresql
sudo -u postgres psql -d <DB_NAME> -c "SELECT 1;"
```

## Certificate renewal

```bash
sudo certbot certificates
sudo certbot renew --dry-run
```

## Git deployment state

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git status --short --branch
git log -1 --oneline
git remote -v
'
```

## Interpret before changing

| Result | Meaning | Next step |
|---|---|---|
| Proxy config invalid | web server cannot safely reload | fix config syntax/path before restart |
| App service inactive | upstream unavailable | read app journal, do not only restart repeatedly |
| localhost app works but public domain fails | proxy/DNS/firewall/TLS issue | inspect web-server access/error logs |
| app returns 500 | Django/config/database issue | read traceback from app journal |
| app returns 404 for one record | URL/data/filter mismatch | inspect generated URL, stored fields, query filters |
| static 404 | collection/alias/permissions mismatch | run collectstatic, verify directory and alias |

---

<!-- Source: reference/glossary.md -->

# Glossary

| Term | Meaning |
|---|---|
| ACME | protocol used by certificate authorities/clients such as Let's Encrypt/Certbot |
| ALLOWED_HOSTS | Django protection against unexpected Host headers |
| ASGI | asynchronous Python web-server gateway interface |
| CDN | geographically distributed proxy/cache layer for public assets or traffic |
| CNAME | DNS record that aliases one hostname to another hostname |
| connection pool | shared set of database connections reused by application processes |
| CSRF | protection against malicious cross-site form submissions |
| daemon | long-running background process/service |
| DNS | system mapping names to IP addresses |
| Gunicorn | Python WSGI application server |
| HSTS | browser policy remembering to use HTTPS |
| HTTP | web request/response protocol |
| HTTPS | HTTP over TLS encryption |
| idempotent task | task that can be retried without causing duplicate harmful effects |
| load balancer | component that distributes traffic across healthy app instances |
| localhost | network name for the same machine, commonly `127.0.0.1` or `::1` |
| migration | versioned Django database schema/data operation |
| mod_wsgi | Apache module hosting Python WSGI apps |
| NAT | network address translation between private and public networks |
| object storage | S3-compatible or cloud storage for files/media outside the app server disk |
| PgBouncer | lightweight PostgreSQL connection pooler |
| private IP | address reachable only inside a private network |
| public IP | address routable from the public internet |
| reverse proxy | public server forwarding requests to private upstream app service |
| socket | endpoint for process communication; can be TCP or Unix file socket |
| systemd | Linux service manager |
| TCP | transport protocol used by HTTP(S), SSH, PostgreSQL, Redis, and many APIs |
| TLS | cryptographic protocol behind HTTPS |
| TTL | DNS cache lifetime value used by resolvers |
| UFW | Ubuntu firewall management frontend |
| Unix socket | same-machine process communication endpoint represented as a file |
| VPS | virtual private server rented from a hosting provider |
| WSGI | traditional synchronous Python web-server gateway interface |
| zero-downtime deployment | deployment approach that keeps serving successful requests during release |

---

<!-- Source: reference/official-sources.md -->

# Official sources and continued learning

Use current official documentation when applying a real deployment. Versions and package behavior change.

- [Django deployment documentation](https://docs.djangoproject.com/en/6.0/howto/deployment/)
- [Django deployment checklist](https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/)
- [Django security documentation](https://docs.djangoproject.com/en/6.0/topics/security/)
- [Django with Apache and mod_wsgi](https://docs.djangoproject.com/en/6.0/howto/deployment/wsgi/modwsgi/)
- [Django with uWSGI](https://docs.djangoproject.com/en/6.0/howto/deployment/wsgi/uwsgi/)
- [Gunicorn deployment documentation](https://gunicorn.org/deploy/)
- [Nginx documentation](https://nginx.org/en/docs/)
- [Nginx proxy module](https://nginx.org/en/docs/http/ngx_http_proxy_module.html)
- [Apache HTTP Server documentation](https://httpd.apache.org/docs/2.4/)
- [Caddy reverse proxy quick-start](https://caddyserver.com/docs/quick-starts/reverse-proxy)
- [Caddy automatic HTTPS](https://caddyserver.com/docs/automatic-https)
- [Ubuntu firewall documentation](https://documentation.ubuntu.com/security/security-features/network/firewall/)
- [PostgreSQL documentation](https://www.postgresql.org/docs/)
- [Certbot documentation](https://eff-certbot.readthedocs.io/)
- [Read the Docs: MkDocs projects](https://docs.readthedocs.com/platform/stable/intro/mkdocs.html)
- [MkDocs documentation](https://www.mkdocs.org/)
- [GitHub Actions documentation](https://docs.github.com/actions)
- [Semantic Versioning](https://semver.org/)

Read your installed software’s documentation and release notes before applying version-specific commands in production.

---

<!-- Source: reference/configuration-walkthroughs.md -->

# Configuration walkthroughs: explain every important line

The `config-examples/` directory contains copy-and-adapt starting points. Templates are not magic files. They are examples of how the layers connect. This chapter explains the most important lines so a beginner can edit them without guessing.

## `config-examples/app.env.example`

```dotenv
DJANGO_SECRET_KEY='replace-with-a-long-random-secret'
```

This is the cryptographic secret Django uses for signing data such as sessions and password-reset tokens. In production it must be unique, long, unpredictable, and private. If it leaks, rotate it.

```dotenv
DJANGO_DEBUG=False
```

This disables development debug behavior. Production debug pages can expose settings, paths, SQL, environment details, and stack traces.

```dotenv
DJANGO_ALLOWED_HOSTS=<DOMAIN>,<WWW_DOMAIN>
```

This is the comma-separated list of hostnames Django is allowed to serve. It should match the domains users type into the browser.

```dotenv
DJANGO_CSRF_TRUSTED_ORIGINS=https://<DOMAIN>,https://<WWW_DOMAIN>
```

This is used for CSRF protection on HTTPS forms and unsafe requests. Include the scheme (`https://`) because Django expects origins, not just hostnames.

```dotenv
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

These say Django should connect to PostgreSQL on the same server using PostgreSQL's default TCP port. If you move PostgreSQL to a private managed database, these values change.

## `config-examples/django-production-settings.py`

This file demonstrates a production settings shape. The most important idea is that code contains names of required settings, while the server supplies values.

```python
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
```

The app refuses to start if the secret is missing. That is safer than silently generating a different key on every restart.

```python
DEBUG = env_bool("DJANGO_DEBUG", False)
```

This reads a string from the environment and converts it to a boolean. Never write `DEBUG = os.environ.get("DJANGO_DEBUG")` because the string `"False"` would still behave like true in many Python checks.

```python
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
```

This converts `example.com,www.example.com` into `['example.com', 'www.example.com']`.

```python
"ENGINE": "django.db.backends.postgresql"
```

This tells Django to use PostgreSQL, not SQLite. The database driver must be installed in your Python environment.

```python
"CONN_MAX_AGE": 60
```

This allows Django to reuse database connections for up to 60 seconds. It can improve performance, but too many workers can still create too many database connections.

```python
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

Use this only when the reverse proxy is trusted and Gunicorn/Uvicorn is private. It tells Django that requests with `X-Forwarded-Proto: https` were HTTPS at the public edge.

## `config-examples/gunicorn.service`

```ini
[Unit]
Description=<APP_NAME> Django application via Gunicorn
After=network.target postgresql.service
Wants=postgresql.service
```

`[Unit]` describes the service and its startup relationship. `After` means systemd should start this after the network and PostgreSQL service. `Wants` asks systemd to start PostgreSQL too, but it is not as strict as `Requires`.

```ini
[Service]
Type=simple
```

`Type=simple` means the process started by `ExecStart` is the service process. This fits Gunicorn when it stays in the foreground.

```ini
User=<APP_USER>
Group=<APP_USER>
```

Gunicorn runs as a limited application user. If someone exploits the Python process, they get that user's permissions, not root permissions.

```ini
WorkingDirectory=/srv/<APP_NAME>/app
```

This makes relative paths resolve from the application repository directory.

```ini
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
```

Systemd loads deployment-specific variables before starting Gunicorn.

```ini
ExecStart=/srv/<APP_NAME>/venv/bin/gunicorn \
  --workers 3 \
  --bind 127.0.0.1:8000 \
  --access-logfile - \
  --error-logfile - \
  <PROJECT_PACKAGE>.wsgi:application
```

This starts Gunicorn from the virtual environment, creates three workers, listens only on the local server, sends logs to the journal, and imports Django's WSGI application.

```ini
Restart=on-failure
RestartSec=5
```

If Gunicorn crashes, systemd waits five seconds and starts it again. This helps with unexpected crashes but does not fix a permanent configuration error.

## `config-examples/nginx-site.conf`

```nginx
server_name <DOMAIN> <WWW_DOMAIN>;
```

This must match the hostnames in DNS and Django `ALLOWED_HOSTS`.

```nginx
location /static/ {
    alias /srv/<APP_NAME>/staticfiles/;
}
```

Nginx serves collected static files directly. Django should not spend Python worker time serving CSS, JavaScript, and images in production.

```nginx
location / {
    proxy_pass http://127.0.0.1:8000;
```

Everything else goes to Gunicorn. This is the reverse-proxy handoff.

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

These headers preserve public request information so Django can make correct security and URL decisions.

## `config-examples/docker-compose.yml`

```yaml
services:
```

A Compose file defines named containers that work together.

```yaml
web:
  build: .
  command: gunicorn <PROJECT_PACKAGE>.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

The `web` service builds your app image and runs Gunicorn inside the container. Inside a container, binding to `0.0.0.0` is normal because Docker controls how the container port is exposed.

```yaml
db:
  image: postgres:16
```

The `db` service runs PostgreSQL. Pin a major version deliberately; changing database major versions is an upgrade project, not a casual edit.

```yaml
volumes:
  postgres_data:
```

The database needs persistent storage. Without a volume, deleting the container can delete the database data.

## `config-examples/db-backup.service` and `.timer`

A systemd service describes what one backup run does. A systemd timer describes when that service runs.

```ini
Type=oneshot
```

The backup command runs, finishes, and exits. It is not a long-running daemon.

```ini
UMask=0077
```

New backup files should be private by default. Database dumps can contain user data, password hashes, private content, and business data.

```ini
OnCalendar=*-*-* 03:15:00 UTC
Persistent=true
```

This schedules the backup every day at 03:15 UTC. `Persistent=true` lets systemd run a missed timer after the machine comes back online.

## `config-examples/apache-gunicorn.conf`

```apache
<VirtualHost *:80>
```

This starts an Apache site that accepts HTTP requests on port 80.

```apache
ServerName <DOMAIN>
ServerAlias <WWW_DOMAIN>
```

These hostnames decide which requests belong to this site. They should match DNS, TLS certificate names, and Django `ALLOWED_HOSTS`.

```apache
Alias /static/ /srv/<APP_NAME>/staticfiles/
<Directory /srv/<APP_NAME>/staticfiles/>
    Require all granted
</Directory>
```

`Alias` maps the URL path to a directory. The `<Directory>` block permits Apache to serve that directory. Apache needs both the mapping and the permission.

```apache
ProxyPreserveHost On
```

Pass the browser's original hostname through to Django instead of replacing it with `127.0.0.1:8000`.

```apache
RequestHeader set X-Forwarded-Proto "http"
```

Tell Django the original public scheme. In the HTTPS vhost this should become `https`.

```apache
ProxyPass /static/ !
ProxyPass /media/ !
```

Exclude static and media paths from proxying. Apache serves those files directly.

```apache
ProxyPass / http://127.0.0.1:8000/
ProxyPassReverse / http://127.0.0.1:8000/
```

Forward dynamic requests to private Gunicorn and rewrite upstream redirect headers back into public-facing URLs.

## `config-examples/apache-modwsgi.conf`

```apache
WSGIDaemonProcess <APP_NAME> \
    python-home=/srv/<APP_NAME>/venv \
    python-path=/srv/<APP_NAME>/app \
    processes=2 threads=15
```

Create a mod_wsgi daemon group for the Django app. `python-home` points to the virtualenv. `python-path` points to the project source. `processes` and `threads` control concurrency.

```apache
WSGIProcessGroup <APP_NAME>
```

Use that daemon group for this virtual host.

```apache
WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py
```

Map the entire site to Django's WSGI entrypoint file.

```apache
<Files wsgi.py>
    Require all granted
</Files>
```

Allow Apache to load the WSGI entrypoint. This is not a permission to expose all source files as downloads.

## `config-examples/Caddyfile`

```caddyfile
<DOMAIN>, <WWW_DOMAIN> {
```

Define the hostnames for this site. Caddy uses these names for automatic HTTPS when DNS points to the server.

```caddyfile
encode zstd gzip
```

Enable compression for suitable responses.

```caddyfile
handle_path /static/* {
    root * /srv/<APP_NAME>/staticfiles
    file_server
}
```

Serve static files directly. `handle_path` strips `/static` before file lookup, so test paths carefully.

```caddyfile
reverse_proxy 127.0.0.1:8000 {
```

Forward dynamic requests to private Gunicorn.

```caddyfile
header_up X-Forwarded-Proto {scheme}
```

Tell Django whether the original request was HTTP or HTTPS.

## `config-examples/uvicorn.service`

```ini
ExecStart=/srv/<APP_NAME>/venv/bin/uvicorn \
  <PROJECT_PACKAGE>.asgi:application \
  --host 127.0.0.1 \
  --port 8001 \
  --proxy-headers
```

Start Uvicorn from the virtualenv, import Django's ASGI application, listen privately on localhost, use port 8001, and honor trusted proxy headers. Use this for ASGI/WebSocket deployments, not just because it is newer.

## `config-examples/ci.yml`

```yaml
name: Django CI
on:
  push:
  pull_request:
```

Name the workflow and run it on pushes and pull requests.

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
```

Download the repository and install the requested Python version on the GitHub runner.

```yaml
- run: python manage.py check
- run: python manage.py test
```

Run Django checks and tests. These commands must pass before you trust the change.

## `config-examples/db-backup.sh`

```bash
set -Eeuo pipefail
```

Stop the script when commands fail, unset variables are used, or pipelines fail.

```bash
install -d -m 700 "$BACKUP_DIR"
```

Create the backup directory with private permissions.

```bash
sudo -u postgres pg_dump --format=custom --no-owner --no-privileges --file="$FILE" "$DB_NAME"
```

Create a PostgreSQL custom-format backup file. Custom format is intended for `pg_restore`.

```bash
sudo -u postgres pg_restore --list "$FILE" > /dev/null
```

Verify that PostgreSQL can read the backup archive structure.

## Development config versus production config

Development config often optimizes for speed and convenience:

| Development shortcut | Why it changes in production |
|---|---|
| `DEBUG=True` | exposes sensitive error details |
| SQLite file in repo directory | weak fit for multi-user concurrent writes and backups |
| `runserver` | not a production process manager |
| localhost-only testing | does not test DNS, TLS, proxy headers, or firewall rules |
| permissive CORS/hosts | weakens browser and host-header protections |
| local console email backend | does not prove real delivery |
| mounted source code in containers | not the same as immutable deployed images |

A good development config is allowed to be convenient. The danger is copying that convenience into production without noticing what guarantee was lost.

## How to adapt a template safely

Use this checklist every time you copy a template:

```text
[ ] Replace every placeholder: <APP_NAME>, <DOMAIN>, <PROJECT_PACKAGE>, users, database names.
[ ] Confirm file paths exist on the server.
[ ] Confirm ownership and permissions match the service user.
[ ] Test syntax: nginx -t, apache2ctl configtest, caddy validate, systemd daemon-reload.
[ ] Start or reload the service.
[ ] Read logs immediately after startup.
[ ] Test the public URL and health check.
[ ] Confirm static files, media files, admin, login, forms, and one critical user flow.
```

If you cannot explain a line, leave a note and look it up before production use. Unknown config is operational debt.

---
