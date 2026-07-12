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
