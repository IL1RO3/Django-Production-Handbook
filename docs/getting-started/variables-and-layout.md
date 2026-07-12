# 4. Variables and target layout

Every config in this book uses placeholders. Define them once before editing files.

| Placeholder | Example | Meaning |
|---|---|---|
| `<APP_NAME>` | `myproject` | service/directory/database naming prefix |
| `<PROJECT_PACKAGE>` | `myproject` | Python package containing `settings.py`, `wsgi.py`, `asgi.py` |
| `<DOMAIN>` | `example.com` | canonical public hostname |
| `<WWW_DOMAIN>` | `www.example.com` | optional alternate hostname |
| `<DEPLOY_USER>` | `deploy` | SSH/Git maintenance account |
| `<APP_USER>` | `myproject` | non-login Linux user that runs Python service |
| `<DB_NAME>` | `myproject` | PostgreSQL database |
| `<DB_USER>` | `myproject_db` | PostgreSQL login role |

## Suggested single-VPS layout

```text
/srv/<APP_NAME>/
├── app/               # Git checkout
├── venv/              # Python virtual environment
├── staticfiles/       # collectstatic output
└── media/             # user uploads, if you use local media

/etc/<APP_NAME>/
├── <APP_NAME>.env     # secrets/environment; not Git
└── ...                # optional DB service/pass files

/run/<APP_NAME>/       # runtime socket/PID directory created by systemd

/var/backups/<APP_NAME>/
└── postgresql/        # database dump files, private permissions
```

## Why use distinct users?

A useful split is:

- `<DEPLOY_USER>` owns the Git checkout and runs Git operations.
- `<APP_USER>` runs Gunicorn/Uvicorn/Django and only needs read access to code plus write access where Django actually writes.
- `postgres` runs the database service and owns database backups if you use local peer-authenticated backup jobs.
- `www-data` or the web-server user needs read access to static/media directories only.

This is least privilege in practice: a compromised process should not automatically inherit the ability to edit source code, read every secret, or manage the entire server.

## Naming discipline matters

Use the same app prefix in service names, directories, database names, backup paths, and log names. A future you should be able to answer “which service owns this file?” from the name alone.
