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
