# Django Production Deployment Guide

> A GitBook-ready, docs-as-code handbook for moving a bare Django project from a developer laptop to a secure, repeatable production service.

This guide is deliberately **explanatory**. It teaches what each layer is, why it exists, when to choose it, how the pieces communicate, how to configure them, and how to operate the system after launch.

## Who this is for

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

1. Read [Mental model](foundations/01-mental-model.md).
2. Read [Choose your architecture](foundations/03-choose-your-stack.md).
3. Follow the [reference deployment path](stacks/02-nginx-gunicorn-postgres.md) for a first VPS deployment.
4. Do not skip [security](operations/02-firewall-ssh-and-host-security.md), [backups](operations/05-backups-and-disaster-recovery.md), or [open-source publication](open-source/01-publishing-a-project.md).

## How to use this as GitBook

This repository contains `README.md` and `SUMMARY.md` navigation plus plain Markdown pages. Push it to GitHub/GitLab, then connect the repository to a GitBook Space using Git Sync/import. See [GitBook setup](GITBOOK_SETUP.md).

## Safety rule

Every command is a template. Replace placeholders such as `<APP_NAME>`, `<DOMAIN>`, `<DEPLOY_USER>`, and `<PROJECT_PACKAGE>`. Read the explanation and verification step before applying it to a live system.
