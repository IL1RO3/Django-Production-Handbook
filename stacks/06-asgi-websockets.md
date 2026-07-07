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
