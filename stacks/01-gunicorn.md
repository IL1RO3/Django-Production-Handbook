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
