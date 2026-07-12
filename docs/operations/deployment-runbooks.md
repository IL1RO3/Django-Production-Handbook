# 26. Safe deployments, migrations, and rollbacks

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

## Why the runbook uses `sudo -u ... bash -lc`

Many deployment commands must run as a specific Linux identity.

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
git pull --ff-only origin main
'
```

Read it piece by piece:

| Piece | Meaning |
|---|---|
| `sudo -u <DEPLOY_USER>` | run the command as the deploy user, not root |
| `-H` | use that user's home directory environment |
| `bash -lc` | start a login-like shell and run the quoted commands |
| `cd /srv/<APP_NAME>/app` | move into the repository |
| `git pull --ff-only origin main` | update only if Git can move forward without a merge commit |

The same pattern appears with `<APP_USER>` for Django commands because migrations and checks should run with the same environment and permissions as the application service.

## Why `set -Eeuo pipefail` appears in scripts

```bash
set -Eeuo pipefail
```

This makes shell scripts fail earlier and more honestly:

| Option | Meaning |
|---|---|
| `-E` | preserve error traps in functions/subshells when used |
| `-e` | stop when a command fails |
| `-u` | fail when an unset variable is used |
| `-o pipefail` | fail a pipeline if any important command in it fails |

Without this, a script can keep going after a failed command and make the server state confusing.

## What each Django deploy command does

```bash
/srv/<APP_NAME>/venv/bin/python manage.py check
```

Runs Django's system checks. It catches many configuration mistakes before the app restarts.

```bash
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
```

Applies unapplied database migrations. `--noinput` prevents the command from waiting for keyboard input during an automated deployment.

```bash
/srv/<APP_NAME>/venv/bin/python manage.py collectstatic --noinput
```

Copies static assets from apps and project directories into `STATIC_ROOT`, where the web server can serve them.

## Beginner rollback examples

If the new code is bad but the database is still compatible, a simple rollback may be:

```bash
sudo -u <DEPLOY_USER> -H bash -lc '
set -Eeuo pipefail
cd /srv/<APP_NAME>/app
git checkout <KNOWN_GOOD_COMMIT>
'
sudo systemctl restart <APP_NAME>
```

If migrations changed the database in a non-compatible way, code rollback may not be enough. You may need a forward fix, a reverse migration that was designed and tested, or a database restore. This is why risky migrations need a deployment plan before they reach production.
