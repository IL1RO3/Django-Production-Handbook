# 5. Repository hygiene and dependencies

A production deployment begins before the server exists. The repository should reproduce **code**, not contain production secrets or runtime artifacts.

## Minimum repository structure

```text
myproject/
├── manage.py
├── pyproject.toml or requirements.txt
├── myproject/
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── web/
├── config-examples/
├── static/
├── deploy/                 # public config-examples/scripts only
├── docs/
├── README.md
├── LICENSE
├── SECURITY.md
└── .gitignore
```

## What belongs in Git

Commit:

- source code, templates, migrations, static source files;
- dependency declaration/lock files;
- non-secret deployment templates;
- documentation, tests, CI configuration;
- `.env.example` with placeholder values.

Do **not** commit:

- production `.env` files;
- `SECRET_KEY`, tokens, private keys, database passwords;
- virtual environments, `__pycache__`, SQLite production data, generated `staticfiles`, user uploads, socket/PID files;
- server-specific Apache/Nginx config containing secrets.

## Example `.gitignore`

```gitignore
# Python
__pycache__/
*.py[cod]
.venv/
venv/

# Django runtime state
*.sqlite3
staticfiles/
media/

# Secrets
.env
.env.*
!.env.example

# Editor/OS
.vscode/
.idea/
.DS_Store
```

## Dependency management choices

You need a reproducible answer to “which versions did production run?”

| Option | Good for | Key point |
|---|---|---|
| `requirements.txt` | simple Django projects | pin direct and/or resolved versions deliberately |
| `pip-tools` | pip workflow with compiled lock files | maintain input requirements and generated lock output |
| Poetry | projects wanting lockfile + packaging workflow | use `pyproject.toml` and `poetry.lock` |
| uv | fast modern Python workflow | commit its lock file and document commands |

The tool matters less than committing the resolved dependency state and using the same file locally, in CI, and in deployment.

## Local pre-deploy quality gate

Before pushing a release:

```bash
python manage.py test
python manage.py check
python manage.py check --deploy  # review warnings in production-like settings
python manage.py makemigrations --check --dry-run
```

Then inspect Git:

```bash
git status --short
git diff --check
git log -1 --oneline
```

A clean working tree does not prove the app is correct; it proves you know which code you are about to ship.

## Migrations are production changes

A migration is code that changes data structure. Treat it as part of the release, not an afterthought.

- Review generated migrations.
- Think about table size and locks for large databases.
- Back up before risky migrations.
- Have a rollback/forward-fix plan.
- Never edit a migration that has already been applied to shared production history unless you understand the consequences.
