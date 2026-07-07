# 18. ASGI: Uvicorn, Daphne, Hypercorn, and WebSockets

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
