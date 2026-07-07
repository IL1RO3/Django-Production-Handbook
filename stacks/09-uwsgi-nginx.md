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
