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
