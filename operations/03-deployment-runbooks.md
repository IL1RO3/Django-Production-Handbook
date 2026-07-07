# 23. Safe deployments, migrations, and rollbacks

A deployment should be a documented operation, not a memory test.

## Standard workflow

```text
local branch
→ tests/checks
→ commit
→ push to Git remote
→ inspect server state
→ pull exact code as deploy user
→ migrate if needed
→ collectstatic if needed
→ restart/reload service
→ smoke test
→ monitor logs
```

## Before deployment

Locally:

```bash
python manage.py test
python manage.py check
git status --short
git diff --check
git log -1 --oneline
```

On server:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git status --short --branch
git fetch origin
git log --oneline HEAD..origin/main
'
```

If the server working tree is dirty, understand why before pulling. Do not normalize `git reset --hard` as a deployment tool; it can erase uncommitted server state and hide process problems.

## Pull code safely

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
git pull --ff-only origin main
'
```

`--ff-only` prevents Git from creating an unexpected merge commit on the server. It stops when history cannot advance safely.

## Apply Django-level changes as the app user

```bash
sudo -u <APP_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py check
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
'
```

Run `migrate` when the release includes migrations; run `collectstatic` when static sources/settings changed. They are not magic rituals required for every Python edit.

## Reload the running app

For Gunicorn/Uvicorn under systemd:

```bash
sudo systemctl restart <APP_NAME>
```

For Apache/Nginx config edits:

```bash
sudo nginx -t && sudo systemctl reload nginx
# or
sudo apache2ctl configtest && sudo systemctl reload apache2
```

## Post-deploy verification

```bash
curl -fsS https://<DOMAIN>/healthz/
curl -I https://<DOMAIN>/
sudo systemctl --no-pager --full status <APP_NAME>
sudo journalctl -u <APP_NAME> -n 50 --no-pager
```

Then manually test the critical user path that changed.

## Rollback philosophy

A clean rollback needs an earlier known-good Git commit/tag and an understanding of database compatibility. Code can often roll back quickly; schema/data changes may not. For risky migrations, plan a forward fix, a restore path, or a two-step compatible deployment rather than assuming `git checkout` solves every outage.
