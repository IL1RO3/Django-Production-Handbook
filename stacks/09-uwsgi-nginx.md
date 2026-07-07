# 21. uWSGI + Nginx

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
