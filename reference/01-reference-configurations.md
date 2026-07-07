# Reference configurations

This page links to the templates in `templates/`. They are intentionally generic and use placeholders.

| File | Use |
|---|---|
| [`templates/gunicorn.service`](../templates/gunicorn.service) | WSGI application systemd service |
| [`templates/uvicorn.service`](../templates/uvicorn.service) | ASGI application systemd service |
| [`templates/nginx-site.conf`](../templates/nginx-site.conf) | Nginx public proxy/static/TLS vhost shape |
| [`templates/apache-gunicorn.conf`](../templates/apache-gunicorn.conf) | Apache reverse proxy vhost shape |
| [`templates/apache-modwsgi.conf`](../templates/apache-modwsgi.conf) | Apache daemon-mode mod_wsgi vhost shape |
| [`templates/Caddyfile`](../templates/Caddyfile) | Caddy reverse proxy/static pattern |
| [`templates/django-production-settings.py`](../templates/django-production-settings.py) | production settings fragments |
| [`templates/app.env.example`](../templates/app.env.example) | environment variable names only |
| [`templates/db-backup.sh`](../templates/db-backup.sh) | database backup/verification pattern |
| [`templates/db-backup.service`](../templates/db-backup.service) | backup service |
| [`templates/db-backup.timer`](../templates/db-backup.timer) | nightly backup timer |
| [`templates/ci.yml`](../templates/ci.yml) | GitHub Actions basic test job |
| [`templates/docker-compose.yml`](../templates/docker-compose.yml) | conceptual Compose topology |

Read the accompanying stack/operations chapter before using a template. Config files are not interchangeable: proxy headers, locations, socket paths, users, and TLS ownership must match the selected stack.
