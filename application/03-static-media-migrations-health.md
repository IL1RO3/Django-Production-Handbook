# 7. Static files, media, migrations, and health checks

## Static files and media are not the same

| Type | Examples | Source of truth | Production strategy |
|---|---|---|---|
| Static files | CSS, JavaScript, logos shipped with code | Git repository | `collectstatic`, then serve directly via proxy/web server |
| Media files | user uploads, avatars, attachments | runtime data | persistent storage and backup; often object storage later |

`collectstatic` gathers app-level static source into `STATIC_ROOT`. It does **not** handle user uploads and it does not replace a web server.

## Run collectstatic deliberately

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
'
```

Run it when static sources or static settings change. You do not need it for an ordinary Python-only fix.

## Migrations

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
'
```

Run it only when a new migration is part of the release. It is safe to include in a standard runbook for small apps, but understand that large or complex migrations can lock tables or take time.

## Add a tiny health endpoint

A health endpoint gives monitors and operators a stable request to test. Keep it simple; do not expose secrets or expensive queries.

```python
# web/views.py
from django.http import JsonResponse

def healthz(request):
    return JsonResponse({"status": "ok"})
```

```python
# <PROJECT_PACKAGE>/urls.py
from django.urls import path
from web.views import healthz

urlpatterns = [
    path("healthz/", healthz, name="healthz"),
]
```

A deeper readiness check may test database connectivity, but distinguish it from a lightweight liveness check. A health page that always queries external APIs can create an outage amplifier.

## Production smoke test

After deployment, verify:

```bash
curl -fsS https://<DOMAIN>/healthz/
curl -I https://<DOMAIN>/
```

Then exercise one critical authenticated path manually or with browser automation: login, create/update a representative record, and inspect the expected response.
