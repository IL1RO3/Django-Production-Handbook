# Template walkthroughs: explain every important line

The `templates/` directory contains copy-and-adapt starting points. Templates are not magic files. They are examples of how the layers connect. This chapter explains the most important lines so a beginner can edit them without guessing.

## `templates/app.env.example`

```dotenv
DJANGO_SECRET_KEY='replace-with-a-long-random-secret'
```

This is the cryptographic secret Django uses for signing data such as sessions and password-reset tokens. In production it must be unique, long, unpredictable, and private. If it leaks, rotate it.

```dotenv
DJANGO_DEBUG=False
```

This disables development debug behavior. Production debug pages can expose settings, paths, SQL, environment details, and stack traces.

```dotenv
DJANGO_ALLOWED_HOSTS=<DOMAIN>,<WWW_DOMAIN>
```

This is the comma-separated list of hostnames Django is allowed to serve. It should match the domains users type into the browser.

```dotenv
DJANGO_CSRF_TRUSTED_ORIGINS=https://<DOMAIN>,https://<WWW_DOMAIN>
```

This is used for CSRF protection on HTTPS forms and unsafe requests. Include the scheme (`https://`) because Django expects origins, not just hostnames.

```dotenv
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

These say Django should connect to PostgreSQL on the same server using PostgreSQL's default TCP port. If you move PostgreSQL to a private managed database, these values change.

## `templates/django-production-settings.py`

This file demonstrates a production settings shape. The most important idea is that code contains names of required settings, while the server supplies values.

```python
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
```

The app refuses to start if the secret is missing. That is safer than silently generating a different key on every restart.

```python
DEBUG = env_bool("DJANGO_DEBUG", False)
```

This reads a string from the environment and converts it to a boolean. Never write `DEBUG = os.environ.get("DJANGO_DEBUG")` because the string `"False"` would still behave like true in many Python checks.

```python
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
```

This converts `example.com,www.example.com` into `['example.com', 'www.example.com']`.

```python
"ENGINE": "django.db.backends.postgresql"
```

This tells Django to use PostgreSQL, not SQLite. The database driver must be installed in your Python environment.

```python
"CONN_MAX_AGE": 60
```

This allows Django to reuse database connections for up to 60 seconds. It can improve performance, but too many workers can still create too many database connections.

```python
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

Use this only when the reverse proxy is trusted and Gunicorn/Uvicorn is private. It tells Django that requests with `X-Forwarded-Proto: https` were HTTPS at the public edge.

## `templates/gunicorn.service`

```ini
[Unit]
Description=<APP_NAME> Django application via Gunicorn
After=network.target postgresql.service
Wants=postgresql.service
```

`[Unit]` describes the service and its startup relationship. `After` means systemd should start this after the network and PostgreSQL service. `Wants` asks systemd to start PostgreSQL too, but it is not as strict as `Requires`.

```ini
[Service]
Type=simple
```

`Type=simple` means the process started by `ExecStart` is the service process. This fits Gunicorn when it stays in the foreground.

```ini
User=<APP_USER>
Group=<APP_USER>
```

Gunicorn runs as a limited application user. If someone exploits the Python process, they get that user's permissions, not root permissions.

```ini
WorkingDirectory=/srv/<APP_NAME>/app
```

This makes relative paths resolve from the application repository directory.

```ini
EnvironmentFile=/etc/<APP_NAME>/<APP_NAME>.env
```

Systemd loads deployment-specific variables before starting Gunicorn.

```ini
ExecStart=/srv/<APP_NAME>/venv/bin/gunicorn \
  --workers 3 \
  --bind 127.0.0.1:8000 \
  --access-logfile - \
  --error-logfile - \
  <PROJECT_PACKAGE>.wsgi:application
```

This starts Gunicorn from the virtual environment, creates three workers, listens only on the local server, sends logs to the journal, and imports Django's WSGI application.

```ini
Restart=on-failure
RestartSec=5
```

If Gunicorn crashes, systemd waits five seconds and starts it again. This helps with unexpected crashes but does not fix a permanent configuration error.

## `templates/nginx-site.conf`

```nginx
server_name <DOMAIN> <WWW_DOMAIN>;
```

This must match the hostnames in DNS and Django `ALLOWED_HOSTS`.

```nginx
location /static/ {
    alias /srv/<APP_NAME>/staticfiles/;
}
```

Nginx serves collected static files directly. Django should not spend Python worker time serving CSS, JavaScript, and images in production.

```nginx
location / {
    proxy_pass http://127.0.0.1:8000;
```

Everything else goes to Gunicorn. This is the reverse-proxy handoff.

```nginx
proxy_set_header Host $host;
proxy_set_header X-Forwarded-Proto $scheme;
```

These headers preserve public request information so Django can make correct security and URL decisions.

## `templates/docker-compose.yml`

```yaml
services:
```

A Compose file defines named containers that work together.

```yaml
web:
  build: .
  command: gunicorn <PROJECT_PACKAGE>.wsgi:application --bind 0.0.0.0:8000 --workers 3
```

The `web` service builds your app image and runs Gunicorn inside the container. Inside a container, binding to `0.0.0.0` is normal because Docker controls how the container port is exposed.

```yaml
db:
  image: postgres:16
```

The `db` service runs PostgreSQL. Pin a major version deliberately; changing database major versions is an upgrade project, not a casual edit.

```yaml
volumes:
  postgres_data:
```

The database needs persistent storage. Without a volume, deleting the container can delete the database data.

## `templates/db-backup.service` and `.timer`

A systemd service describes what one backup run does. A systemd timer describes when that service runs.

```ini
Type=oneshot
```

The backup command runs, finishes, and exits. It is not a long-running daemon.

```ini
UMask=0077
```

New backup files should be private by default. Database dumps can contain user data, password hashes, private content, and business data.

```ini
OnCalendar=*-*-* 03:15:00 UTC
Persistent=true
```

This schedules the backup every day at 03:15 UTC. `Persistent=true` lets systemd run a missed timer after the machine comes back online.

## `templates/apache-gunicorn.conf`

```apache
<VirtualHost *:80>
```

This starts an Apache site that accepts HTTP requests on port 80.

```apache
ServerName <DOMAIN>
ServerAlias <WWW_DOMAIN>
```

These hostnames decide which requests belong to this site. They should match DNS, TLS certificate names, and Django `ALLOWED_HOSTS`.

```apache
Alias /static/ /srv/<APP_NAME>/staticfiles/
<Directory /srv/<APP_NAME>/staticfiles/>
    Require all granted
</Directory>
```

`Alias` maps the URL path to a directory. The `<Directory>` block permits Apache to serve that directory. Apache needs both the mapping and the permission.

```apache
ProxyPreserveHost On
```

Pass the browser's original hostname through to Django instead of replacing it with `127.0.0.1:8000`.

```apache
RequestHeader set X-Forwarded-Proto "http"
```

Tell Django the original public scheme. In the HTTPS vhost this should become `https`.

```apache
ProxyPass /static/ !
ProxyPass /media/ !
```

Exclude static and media paths from proxying. Apache serves those files directly.

```apache
ProxyPass / http://127.0.0.1:8000/
ProxyPassReverse / http://127.0.0.1:8000/
```

Forward dynamic requests to private Gunicorn and rewrite upstream redirect headers back into public-facing URLs.

## `templates/apache-modwsgi.conf`

```apache
WSGIDaemonProcess <APP_NAME> \
    python-home=/srv/<APP_NAME>/venv \
    python-path=/srv/<APP_NAME>/app \
    processes=2 threads=15
```

Create a mod_wsgi daemon group for the Django app. `python-home` points to the virtualenv. `python-path` points to the project source. `processes` and `threads` control concurrency.

```apache
WSGIProcessGroup <APP_NAME>
```

Use that daemon group for this virtual host.

```apache
WSGIScriptAlias / /srv/<APP_NAME>/app/<PROJECT_PACKAGE>/wsgi.py
```

Map the entire site to Django's WSGI entrypoint file.

```apache
<Files wsgi.py>
    Require all granted
</Files>
```

Allow Apache to load the WSGI entrypoint. This is not a permission to expose all source files as downloads.

## `templates/Caddyfile`

```caddyfile
<DOMAIN>, <WWW_DOMAIN> {
```

Define the hostnames for this site. Caddy uses these names for automatic HTTPS when DNS points to the server.

```caddyfile
encode zstd gzip
```

Enable compression for suitable responses.

```caddyfile
handle_path /static/* {
    root * /srv/<APP_NAME>/staticfiles
    file_server
}
```

Serve static files directly. `handle_path` strips `/static` before file lookup, so test paths carefully.

```caddyfile
reverse_proxy 127.0.0.1:8000 {
```

Forward dynamic requests to private Gunicorn.

```caddyfile
header_up X-Forwarded-Proto {scheme}
```

Tell Django whether the original request was HTTP or HTTPS.

## `templates/uvicorn.service`

```ini
ExecStart=/srv/<APP_NAME>/venv/bin/uvicorn \
  <PROJECT_PACKAGE>.asgi:application \
  --host 127.0.0.1 \
  --port 8001 \
  --proxy-headers
```

Start Uvicorn from the virtualenv, import Django's ASGI application, listen privately on localhost, use port 8001, and honor trusted proxy headers. Use this for ASGI/WebSocket deployments, not just because it is newer.

## `templates/ci.yml`

```yaml
name: Django CI
on:
  push:
  pull_request:
```

Name the workflow and run it on pushes and pull requests.

```yaml
- uses: actions/checkout@v4
- uses: actions/setup-python@v5
```

Download the repository and install the requested Python version on the GitHub runner.

```yaml
- run: python manage.py check
- run: python manage.py test
```

Run Django checks and tests. These commands must pass before you trust the change.

## `templates/db-backup.sh`

```bash
set -Eeuo pipefail
```

Stop the script when commands fail, unset variables are used, or pipelines fail.

```bash
install -d -m 700 "$BACKUP_DIR"
```

Create the backup directory with private permissions.

```bash
sudo -u postgres pg_dump --format=custom --no-owner --no-privileges --file="$FILE" "$DB_NAME"
```

Create a PostgreSQL custom-format backup file. Custom format is intended for `pg_restore`.

```bash
sudo -u postgres pg_restore --list "$FILE" > /dev/null
```

Verify that PostgreSQL can read the backup archive structure.

## Development config versus production config

Development config often optimizes for speed and convenience:

| Development shortcut | Why it changes in production |
|---|---|
| `DEBUG=True` | exposes sensitive error details |
| SQLite file in repo directory | weak fit for multi-user concurrent writes and backups |
| `runserver` | not a production process manager |
| localhost-only testing | does not test DNS, TLS, proxy headers, or firewall rules |
| permissive CORS/hosts | weakens browser and host-header protections |
| local console email backend | does not prove real delivery |
| mounted source code in containers | not the same as immutable deployed images |

A good development config is allowed to be convenient. The danger is copying that convenience into production without noticing what guarantee was lost.

## How to adapt a template safely

Use this checklist every time you copy a template:

```text
[ ] Replace every placeholder: <APP_NAME>, <DOMAIN>, <PROJECT_PACKAGE>, users, database names.
[ ] Confirm file paths exist on the server.
[ ] Confirm ownership and permissions match the service user.
[ ] Test syntax: nginx -t, apache2ctl configtest, caddy validate, systemd daemon-reload.
[ ] Start or reload the service.
[ ] Read logs immediately after startup.
[ ] Test the public URL and health check.
[ ] Confirm static files, media files, admin, login, forms, and one critical user flow.
```

If you cannot explain a line, leave a note and look it up before production use. Unknown config is operational debt.
