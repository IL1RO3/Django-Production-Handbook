# 11. PostgreSQL: the private data layer

PostgreSQL is a relational database server. Django’s ORM translates model operations into SQL, while PostgreSQL handles durable storage, transactions, concurrent access, indexes, constraints, and backups.

## Why PostgreSQL instead of SQLite in production?

SQLite is excellent for local prototypes and small single-process projects. PostgreSQL is a more appropriate default for a multi-user production web application because it handles concurrent writes, roles, backups, transactions, and operational tooling more predictably.

## Install packages

```bash
sudo apt install -y postgresql postgresql-contrib libpq-dev
```

## Create a dedicated database and role

```bash
sudo -u postgres psql
```

Inside PostgreSQL:

```sql
CREATE ROLE <DB_USER> LOGIN PASSWORD 'use-a-unique-long-password';
CREATE DATABASE <DB_NAME> OWNER <DB_USER>;
\q
```

Do not use the `postgres` superuser as your Django database user. The application role should own only what it needs.

## Keep PostgreSQL private

For a single-VPS deployment, Django and PostgreSQL communicate locally. Do not add a public UFW rule for port 5432. Do not bind PostgreSQL to public interfaces unless you have a private-network database architecture, TLS, source restriction, and a documented reason.

## Verify Django connection

After environment variables and dependencies are configured:

```bash
sudo -u <APP_USER> -H bash -lc '
cd /srv/<APP_NAME>/app
/srv/<APP_NAME>/venv/bin/python manage.py migrate --noinput
'
```

## Database lifecycle rules

- Schema changes are Django migrations in Git.
- Data is not in Git; it is protected by backup/restore.
- Test restores into a separate database.
- Do not run application management commands as `root`; run them as the app service identity with real production environment variables loaded.
- Keep the database version and backup format documented before a server migration.
