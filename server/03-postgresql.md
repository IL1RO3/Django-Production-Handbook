# 12. PostgreSQL: the private data layer

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

## Authentication and `pg_hba.conf`

PostgreSQL has two separate controls: roles inside the database server and connection rules in `pg_hba.conf`. A role may exist, but a connection can still be rejected if the host, database, user, or authentication method is not allowed.

For a single-VPS deployment, prefer local connections. Keep `listen_addresses` limited to localhost unless you intentionally use a private database network. If you edit PostgreSQL configuration, reload the service and verify with a real Django connection rather than assuming the file is correct.

```bash
sudo systemctl reload postgresql
sudo -u <APP_USER> -H bash -lc 'cd /srv/<APP_NAME>/app && /srv/<APP_NAME>/venv/bin/python manage.py dbshell'
```

## Least-privilege roles

The Django role usually owns the application database and should not be a PostgreSQL superuser. For larger teams, create separate roles for:

| Role | Purpose |
|---|---|
| app role | Django runtime migrations and queries |
| read-only role | analytics or support inspection |
| backup role | dump/replication privileges as needed |
| admin role | controlled maintenance, not used by the app |

Store each credential separately. Do not share the app role password with dashboards, notebooks, or ad hoc scripts.

## Connection pooling

Each Gunicorn/Uvicorn worker can hold database connections. Background workers and management commands add more. If traffic grows, PostgreSQL can run out of connections before CPU is saturated.

Options:

- keep Django `CONN_MAX_AGE` modest and measure connection count;
- tune web worker counts based on memory and database capacity;
- add PgBouncer when connection churn or count becomes a real limit;
- use a managed database pooler if your provider offers one.

Connection pooling is not a substitute for slow-query fixes. Indexes, pagination, and query shape still matter.

## Backups and restore testing

A backup that has never been restored is only a guess. Test restoration into a separate database before you need it during an incident.

Minimum practice:

```text
Nightly logical dump
  -> compressed file
  -> off-server storage
  -> retention policy
  -> scheduled restore drill
```

Record the PostgreSQL version, dump command, restore command, encryption method if used, retention window, and the last successful restore test date.

## Migrations in production

Treat migrations as code, but remember they change data structures. Before deploying risky migrations, ask:

- Does this lock a large table?
- Can old code and new code run during the transition?
- Is there a data backfill, and can it run in batches?
- Is rollback a code rollback, a reverse migration, or a restore?
- Has this migration run against staging data of realistic size?

For large systems, use expand-and-contract migrations: add nullable/new structures first, deploy compatible code, backfill safely, then remove old structures later.

## Basic tuning signals

Do not copy random tuning values. Start by measuring:

| Signal | What it may indicate |
|---|---|
| slow queries | missing indexes, inefficient ORM patterns, too much data per request |
| high connection count | too many workers, missing pooling, long transactions |
| disk growth | missing retention, large uploads in DB, audit/log tables |
| high I/O wait | storage bottleneck, inefficient queries, undersized server |
| lock waits | migration/table lock, long transaction, concurrent writes |

Add indexes with migrations, verify query plans when needed, and keep database monitoring close to deployment history.

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
