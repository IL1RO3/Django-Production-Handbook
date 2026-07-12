# 6. Production settings and secrets

Django settings are where local development assumptions become explicit production behavior.

## Secrets versus configuration

Configuration answers “how should this deployment behave?” Examples: allowed hosts, whether HTTPS is used, email sender.

Secrets answer “what proves identity or grants access?” Examples: `SECRET_KEY`, DB password, API token, SMTP/App Script token.

Both should usually be supplied through protected environment variables. Only secrets are inherently sensitive, but keeping all deployment-specific values outside the code makes one repository usable across development, staging, and production.

## Minimal environment file

Create a **real** file outside Git, e.g. `/etc/<APP_NAME>/<APP_NAME>.env`:

```dotenv
DJANGO_SECRET_KEY='replace-with-a-long-random-value'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=<DOMAIN>,<WWW_DOMAIN>
DJANGO_CSRF_TRUSTED_ORIGINS=https://<DOMAIN>,https://<WWW_DOMAIN>
DJANGO_USE_HTTPS=True

POSTGRES_DB=<DB_NAME>
POSTGRES_USER=<DB_USER>
POSTGRES_PASSWORD='replace-me'
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432

DEFAULT_FROM_EMAIL='My Project <noreply@<DOMAIN>>'
```

Use restrictive ownership/permissions:

```bash
sudo install -d -o root -g <APP_USER> -m 750 /etc/<APP_NAME>
sudo install -o root -g <APP_USER> -m 640 /dev/null /etc/<APP_NAME>/<APP_NAME>.env
sudoedit /etc/<APP_NAME>/<APP_NAME>.env
```

## Example settings pattern

```python
# <PROJECT_PACKAGE>/settings.py
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent

def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}

def env_list(name: str, default: str = "") -> list[str]:
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]

SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
DEBUG = env_bool("DJANGO_DEBUG", False)
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ["POSTGRES_DB"],
        "USER": os.environ["POSTGRES_USER"],
        "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": 60,
    }
}

STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"

USE_HTTPS = env_bool("DJANGO_USE_HTTPS", False)
SECURE_SSL_REDIRECT = USE_HTTPS
SESSION_COOKIE_SECURE = USE_HTTPS
CSRF_COOKIE_SECURE = USE_HTTPS
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
REFERRER_POLICY = "same-origin"
```

## Reverse-proxy HTTPS awareness

When Nginx/Apache/Caddy terminates HTTPS and speaks HTTP to Gunicorn, Django otherwise sees the internal hop as HTTP. Set this **only when the proxy reliably sets the header**:

```python
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

And set the header in the proxy configuration. Misconfiguring this can create redirect loops or cause Django to trust a spoofed header if Gunicorn is publicly reachable. The protection is: bind the app server to `127.0.0.1`/Unix socket and let only your proxy reach it.

## HSTS comes later

HSTS tells browsers to prefer HTTPS for a period. Start with `SECURE_HSTS_SECONDS = 0` or omit it until HTTPS, redirects, and all subdomains are proven stable. Then enable a short period first, validate, and increase deliberately. Do not preload/include subdomains casually.

## Security checks

Run with production variables loaded:

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check --deploy
'
```

Warnings are prompts to understand a decision, not instructions to silence everything blindly.

## Line-by-line explanation of the settings pattern

This section explains the earlier settings example as if you are seeing production settings for the first time.

```python
import os
from pathlib import Path
```

`os` lets Python read environment variables such as `DJANGO_SECRET_KEY` and `POSTGRES_PASSWORD`. `Path` gives a clean way to build filesystem paths without hard-coding slash behavior.

```python
BASE_DIR = Path(__file__).resolve().parent.parent
```

`__file__` is the current settings file. `resolve()` turns it into an absolute path. `parent.parent` walks up to the project base directory. Django uses `BASE_DIR` later for paths such as static files and media files.

```python
def env_bool(name: str, default: bool = False) -> bool:
    return os.environ.get(name, str(default)).lower() in {"1", "true", "yes", "on"}
```

Environment variables are strings. Without conversion, the string `"False"` is still truthy in Python. This helper turns common text values into a real boolean. `DJANGO_DEBUG=False` becomes `False`; `DJANGO_DEBUG=true` becomes `True`.

```python
def env_list(name: str, default: str = "") -> list[str]:
    return [item.strip() for item in os.environ.get(name, default).split(",") if item.strip()]
```

Some Django settings expect a list. The environment file stores `DJANGO_ALLOWED_HOSTS=example.com,www.example.com` as one string. This helper splits it at commas, trims spaces, and removes empty values.

```python
SECRET_KEY = os.environ["DJANGO_SECRET_KEY"]
```

Square brackets mean the setting is required. If the environment variable is missing, Django crashes at startup instead of running with an unsafe fake value. That is good. A missing production secret should be loud.

```python
DEBUG = env_bool("DJANGO_DEBUG", False)
```

`DEBUG` controls detailed error pages and other development behavior. In production it must be false. The default is false so forgetting the variable does not accidentally expose debug pages.

```python
ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS")
```

Django checks the HTTP `Host` header against this list. If your domain is `example.com`, include `example.com`. If you also serve `www.example.com`, include that too. Do not use `*` in normal production because it disables an important host-header protection.

```python
CSRF_TRUSTED_ORIGINS = env_list("DJANGO_CSRF_TRUSTED_ORIGINS")
```

This tells Django which HTTPS origins are allowed to submit unsafe requests such as POST forms. Values include the scheme, for example `https://example.com`, not only the hostname.

```python
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ["POSTGRES_DB"],
        "USER": os.environ["POSTGRES_USER"],
        "PASSWORD": os.environ["POSTGRES_PASSWORD"],
        "HOST": os.environ.get("POSTGRES_HOST", "127.0.0.1"),
        "PORT": os.environ.get("POSTGRES_PORT", "5432"),
        "CONN_MAX_AGE": 60,
    }
}
```

`ENGINE` selects Django's PostgreSQL backend. `NAME`, `USER`, and `PASSWORD` identify the database and role. `HOST=127.0.0.1` means PostgreSQL is on the same server. `PORT=5432` is PostgreSQL's normal TCP port. `CONN_MAX_AGE=60` lets Django reuse a database connection briefly instead of opening a new one for every request.

```python
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
```

`STATIC_URL` is the browser URL prefix. `STATIC_ROOT` is the directory where `collectstatic` gathers CSS, JavaScript, images, and admin assets. Nginx or Apache serves this directory directly.

```python
MEDIA_URL = "/media/"
MEDIA_ROOT = BASE_DIR / "media"
```

Media files are user-uploaded files. They are not the same as static files. They need a backup plan because users create them after deployment.

```python
USE_HTTPS = env_bool("DJANGO_USE_HTTPS", False)
SECURE_SSL_REDIRECT = USE_HTTPS
SESSION_COOKIE_SECURE = USE_HTTPS
CSRF_COOKIE_SECURE = USE_HTTPS
```

These settings switch on HTTPS behavior when the deployment is ready. `SECURE_SSL_REDIRECT` redirects HTTP to HTTPS. The cookie settings tell browsers to send session/CSRF cookies only over HTTPS.

```python
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
REFERRER_POLICY = "same-origin"
```

These are browser security headers. They reduce common classes of mistakes: MIME sniffing, clickjacking, and leaking full referrer URLs across sites.

## Why the environment file is outside Git

A Git repository is copied to laptops, CI systems, GitHub, backups, and sometimes forks. Secrets do not belong there. The application code should say, "I need `POSTGRES_PASSWORD`." The server environment should supply the actual value.

This separation lets you run the same code in multiple places:

| Environment | Same code? | Different values? |
|---|---|---|
| local development | yes | local database, debug true |
| staging | yes | staging domain, staging secrets |
| production | yes | production domain, production secrets |

If a secret leaks, rotate the secret. Do not only delete it from the latest commit; Git history may still contain it.
