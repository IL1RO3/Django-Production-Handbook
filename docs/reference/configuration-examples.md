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

Use [Configuration walkthroughs](configuration-walkthroughs.md) when a config file is correct but still feels mysterious. It explains the important lines in the environment file, Django settings, Gunicorn service, Nginx site, Docker Compose file, and backup timers.
