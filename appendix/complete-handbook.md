# Complete all-in-one handbook

This appendix preserves the earlier linear handbook in one long reading path. The chaptered pages are the preferred GitBook navigation; this version is useful for offline reading, search, and printing.

---

# Complete all-in-one handbook

## From a bare Django project to a secure, understandable, maintainable public service

**Audience:** You know basic Linux commands, Python, Git, and Django. You want to understand what each production component does, why it exists, how it connects to the next component, and how to publish the project responsibly as open source.

**Recommended learning path in this handbook:**

```text
Browser
  -> DNS
  -> provider network firewall
  -> UFW host firewall
  -> Apache HTTP Server
  -> Gunicorn
  -> Django (WSGI)
  -> PostgreSQL
```

This is not a one-command recipe. Each command belongs to a layer, has a purpose, and has a verification step. Read the explanation before applying a command. Replace all placeholders consistently.

> **The central principle:** production is not “the same code on another computer.” Production is code plus a database plus secrets plus operating-system services plus network policy plus backups plus a repeatable way to update and recover it.

<div class="chapter-break"></div>

# Table of contents

1. The mental model: what “deployment” actually means
2. The request journey: one browser request from domain to database
3. The technologies explained: DNS, Apache, Gunicorn, WSGI, systemd, PostgreSQL, UFW, TLS, Certbot, Git
4. Choosing an architecture: Apache + Gunicorn, mod_wsgi, Nginx, ASGI, containers, managed platforms
5. The canonical beginner architecture and why it is recommended
6. Project design before the server exists
7. Making a Django project production-aware
8. Building a clean public repository and publishing it as open source
9. Provisioning a new Ubuntu VPS safely
10. Linux users, directories, ownership, groups, and permissions
11. Installing packages and creating PostgreSQL correctly
12. Production secrets and environment variables
13. Django production settings, explained line by line
14. Gunicorn and systemd, explained line by line
15. Apache reverse proxying, static files, and virtual hosts, explained line by line
16. TLS/HTTPS and Certbot, explained without magic
17. Firewall, SSH, Fail2Ban, updates, and a realistic security baseline
18. Deployment runbooks: normal releases, migrations, static assets, and rollbacks
19. Backups, restores, off-server copies, and disaster recovery
20. Logs, monitoring, health checks, and incident response
21. Testing: unit, integration, browser, staging, and production smoke tests
22. Scaling and architecture changes later
23. Common mistakes, why they happen, and how to recover safely
24. A complete reference configuration
25. Open-source maintenance: releases, SemVer, CI, security policy, issues, contributors
26. Final checklists and glossary
27. Official references

<div class="chapter-break"></div>

# Part I - Understand the system before configuring it

# 1. What production deployment actually means

A Django development server is optimized for *developer feedback*. It reloads code, displays detailed errors, and is easy to start with one command:

```bash
python manage.py runserver
```

That is excellent locally. It is deliberately not a public application server. A public service must survive reboots, accept concurrent requests, protect secrets, terminate encrypted connections, recover from application crashes, and provide enough evidence to debug a failure later.

A production deployment is therefore a system of responsibilities:

| Layer | Main responsibility | Why it exists | Should the public internet reach it directly? |
|---|---|---|---|
| Domain and DNS | Map a human name to an IP address | People remember names; networks route to IPs | DNS is public by design |
| Provider firewall | Filter traffic before it reaches the VPS | Reduces exposed network surface at the provider edge | It is an external boundary |
| UFW | Filter traffic on the Linux host | Enforces a second local boundary | Yes, it sees incoming packets |
| Apache | Accept HTTP/HTTPS, serve files, proxy app requests | Mature TLS, logging, virtual-host, and static-file handling | Yes: ports 80/443 |
| Gunicorn | Run Python worker processes for Django | Makes Django available as a WSGI application service | No: bind to localhost only |
| Django | Application logic, URLs, forms, permissions, ORM | This is your web application | No direct network port |
| PostgreSQL | Durable relational data storage | Data survives process restarts and supports concurrent work | No: localhost/private network only |
| systemd | Start, restart, supervise, and log services | The app must return after a crash or reboot | Local only |
| Certbot / ACME client | Obtain and renew browser-trusted certificates | Browsers require TLS for secure HTTPS | Local only |
| Git and release tags | Track approved source code versions | Makes deployments and rollbacks traceable | Local / remote repository |
| Backups | Preserve recoverable copies of data | Hardware, operator error, and bugs happen | Stored separately from the app |

## 1.1 “Works once” is not deployed

A site is not truly deployed just because it opens in one browser. A minimum production definition is:

- A reboot starts the web server and application automatically.
- The application has no secret values committed to Git.
- The database is private.
- Only the required ports are publicly reachable.
- HTTPS is enforced and certificate renewal is tested.
- An update procedure is written down and repeatable.
- A backup exists, has been verified, and has an off-server copy.
- Logs identify whether a failure belongs to Apache, Gunicorn, Django, PostgreSQL, DNS, or the client.
- The source repository can reproduce the application on a new server.

## 1.2 State is the source of most deployment pain

Your **source code** is only one category of state. These must be separated mentally:

| Category | Examples | Should it be committed to Git? | How is it moved or recovered? |
|---|---|---|---|
| Code | Python, templates, migrations, CSS, deployment templates | Yes | Git clone/pull/tag |
| Configuration | allowed hosts, production mode, email endpoint | Template only | protected environment file or secret manager |
| Secrets | `SECRET_KEY`, database password, API tokens | Never | secure transfer, rotate after exposure |
| Database data | users, posts, orders, sessions | No | tested database backup and restore |
| Uploaded media | avatars, documents, user images | No | file backup / object storage / rsync |
| Generated static files | `collectstatic` output | Usually no | regenerate from committed source |
| Runtime state | PIDs, sockets, caches, log streams | No | recreated by systemd/service startup |

The goal is to make every non-code state category explicit. Hidden state is what makes a server impossible to move or repair safely.

<div class="chapter-break"></div>

# 2. The request journey: from browser to Django and back

Imagine a visitor requests:

```text
https://example.com/blogs/42/
```

The request follows a path. Understanding that path turns debugging from guessing into tracing.

```text
1. Browser asks DNS: “What IP belongs to example.com?”
2. Browser opens a TCP connection to that IP on port 443.
3. Provider firewall and UFW decide whether port 443 is allowed.
4. Apache receives the encrypted HTTPS connection.
5. Apache proves its identity with a TLS certificate and decrypts the HTTP request.
6. Apache serves a static file directly OR proxies a dynamic request to Gunicorn.
7. Gunicorn passes the request into Django through WSGI.
8. Django matches a URL, executes a view, queries PostgreSQL if needed, and creates a response.
9. Response travels back: Django -> Gunicorn -> Apache -> browser.
```

## 2.1 Why there are multiple layers instead of “Django listens on port 443”

Django can technically receive HTTP in development, but each production layer has a specialized job:

- **Apache** is built to manage client connections, TLS, static files, request logs, redirects, and multiple sites.
- **Gunicorn** is built to manage Python worker processes that execute WSGI applications.
- **Django** is built to implement your app’s behavior, not to be a general internet-facing web server.
- **PostgreSQL** is built to keep relational data consistent, not to be exposed to browsers.

This division provides failure boundaries. If Gunicorn crashes, systemd restarts it. Apache can still serve a diagnostic error or static maintenance page. If PostgreSQL is unavailable, logs distinguish an app/database failure from a TLS failure.

## 2.2 A practical troubleshooting map

| Symptom | Most likely layer | First checks |
|---|---|---|
| Domain does not resolve | DNS | `dig`, DNS record, TTL, registrar panel |
| Connection times out | provider firewall, UFW, server availability | provider rules, `ufw status`, service status |
| Browser says certificate invalid | DNS/TLS/Certbot | certificate domain names, renewal, Apache SSL vhost |
| HTTP 502/503 | Apache to Gunicorn path | Gunicorn service, port/bind address, Apache error log |
| HTTP 500 | Django or database | Gunicorn journal, Django traceback, DB credentials |
| HTTP 404 only for one object | URL/view/data logic | generated URL, queryset filters, stored data |
| CSS missing | static configuration | `collectstatic`, Apache `Alias`, directory permissions |
| Login or form gives 403 CSRF | HTTPS/proxy/settings/cookies | trusted origins, forwarded proto, secure cookie settings |
| App works until reboot | systemd service/configuration | `systemctl is-enabled`, service logs |

<div class="chapter-break"></div>

# 3. The technologies explained

# 3.1 VPS and Ubuntu

A **VPS** is a virtual private server: a virtual machine rented from a provider. It gives you an operating system, public IP address, storage, memory, CPU, and root-level administration responsibility.

**Why use it:** flexibility, predictable cost, no platform lock-in, and the ability to run your chosen database/web stack.

**Trade-off:** you are responsible for patching, backups, firewall policy, certificate renewal validation, and recovery. A managed platform moves some of this responsibility away from you.

Ubuntu is a Linux distribution. The guide uses Ubuntu’s package manager (`apt`), service manager (`systemd`), and common host firewall frontend (`ufw`). The concepts also apply to Debian and other Linux systems, but package names and file locations may differ.

# 3.2 DNS

DNS is the internet’s naming system. An **A record** maps a hostname such as `example.com` to an IPv4 address. An **AAAA record** maps it to IPv6. A **CNAME** points one hostname at another hostname.

DNS does not host your application. It only tells clients where to attempt a connection.

Important terms:

- **Registrar:** where the domain is registered.
- **DNS provider:** service that publishes DNS records; it may or may not be the registrar.
- **TTL:** cache lifetime for a DNS answer. A lower TTL changes faster but does not make a mistake disappear instantly everywhere.
- **Apex/root domain:** `example.com`.
- **Subdomain:** `www.example.com`, `api.example.com`, `staging.example.com`.

# 3.3 HTTP, HTTPS, TLS, and certificates

HTTP is the request/response protocol used by browsers. HTTPS is HTTP carried inside TLS encryption.

TLS provides three essential properties:

1. **Confidentiality:** people on the network cannot casually read the contents.
2. **Integrity:** intermediaries cannot silently modify data without detection.
3. **Authentication:** the browser can verify that a certificate is valid for the requested domain.

A certificate does not encrypt your database or make bad code safe. It protects the network connection between client and server.

# 3.4 Apache HTTP Server

Apache is an internet-facing web server. In this guide it has four roles:

- Listen on ports 80 and 443.
- Redirect HTTP to HTTPS.
- Serve static and media files without running Python.
- Reverse proxy dynamic traffic to Gunicorn.

A **virtual host** is an Apache configuration block that says, “For this domain name, use these rules.” One server can host multiple domains through multiple virtual hosts.

# 3.5 Reverse proxy

A reverse proxy receives a client request and forwards it to an internal application server. The client sees Apache as the server. Gunicorn stays private behind it.

```text
Client -> Apache (public) -> Gunicorn (private) -> Django
```

This is different from a forward proxy used by a browser to reach the internet. Apache’s reverse-proxy role is documented around `ProxyPass` and `ProxyPassReverse`. [Apache Proxy]

# 3.6 Gunicorn

Gunicorn is a Python WSGI server. It imports your Django WSGI application and manages worker processes that handle requests.

**Why not run Django directly:** Django’s development server is not designed as the production process manager. Gunicorn is.

**Why bind Gunicorn to `127.0.0.1`:** only Apache on the same machine should reach Gunicorn. The public internet should not see Gunicorn’s port.

**What workers mean:** one worker handles one request at a time in the traditional synchronous model. More workers allow concurrency, but too many can exhaust memory. Start conservatively, measure, and tune later.

# 3.7 WSGI and ASGI

**WSGI** is the long-established Python interface between web servers/application servers and synchronous Python web applications. A traditional Django website works naturally with WSGI.

**ASGI** is a newer asynchronous interface that supports WebSockets and other long-lived async protocols. Django supports both WSGI and ASGI, but you should select ASGI because you need its capabilities, not because it is newer.

Use WSGI/Gunicorn for a normal Django site with forms, admin, REST endpoints, and conventional request/response traffic. Consider ASGI with Uvicorn/Daphne/Hypercorn for WebSockets, live notifications, or async-heavy traffic.

# 3.8 systemd

systemd is the service manager on modern Ubuntu. It starts services at boot, records logs in the journal, restarts failed services according to rules, and tracks their process trees.

For Gunicorn, systemd answers questions Django cannot answer itself:

- Start the app after server boot.
- Restart the app after a crash.
- Run the app as a restricted Linux user.
- Load protected environment variables.
- Provide consistent commands: `start`, `stop`, `restart`, `status`, `enable`.

# 3.9 PostgreSQL

PostgreSQL is a relational database server. Django’s ORM sends SQL queries to it. PostgreSQL stores tables, indexes, constraints, transactions, and data durability information.

**Why PostgreSQL instead of SQLite for a public multi-user app:** SQLite is a file database and excellent for local development/small use cases. PostgreSQL is generally the stronger production default when you need concurrent writes, robust user/role control, backups, operations tooling, and predictable behavior under multi-process web traffic.

PostgreSQL itself has users called **roles**. These are not Linux users and not Django `User` rows. They are database identities.

# 3.10 UFW and provider firewall

A firewall controls network traffic by port, protocol, direction, and sometimes source address.

- A **provider firewall/security group** filters traffic before it reaches your VPS.
- **UFW** configures the Linux host firewall through a simpler interface over the kernel’s packet filtering system. [Ubuntu Firewall]

Use both when possible. They are separate layers.

# 3.11 Certbot and ACME

Let’s Encrypt is a certificate authority. Certbot is an ACME client that proves control over your domain, obtains a certificate, installs or exposes it to your web server, and renews it later.

The validation step is why DNS and firewall configuration must be correct before certificate issuance. For HTTP validation, the CA must reach your domain on port 80.

# 3.12 Git, commits, branches, tags, and releases

- **Commit:** immutable snapshot of code history.
- **Branch:** named line of development pointing at a commit.
- **Tag:** stable human-readable label attached to a commit, often used for versions such as `v0.2.0-beta.3`.
- **Release:** a GitHub presentation layer around a tag, usually with notes and downloadable source archives.

A deployed server should be able to tell you which commit it is running. That is why `git log -1 --oneline` belongs in deployment verification.

<div class="chapter-break"></div>

# Part II - Choose a design deliberately

# 4. Compare the deployment options

There is no single “best” stack. There is a best stack for the application and team you actually have.

| Option | What it is | Advantages | Trade-offs | Good first use case |
|---|---|---|---|---|
| Apache + Gunicorn | Apache handles public HTTP; Gunicorn runs Django | Clear separation, strong Apache tooling, easy static serving | Two services to understand | A conventional Django app on Ubuntu |
| Apache + mod_wsgi | Apache loads Django through mod_wsgi | Fewer moving parts, classic Apache integration | Python/Apache coupling can make environment debugging harder | Existing Apache-first environment |
| Nginx + Gunicorn | Nginx replaces Apache as reverse proxy | Very common, efficient event-driven proxy | Different configuration vocabulary | Teams already familiar with Nginx |
| Caddy + Gunicorn | Caddy reverse proxies with automatic HTTPS emphasis | Simple TLS experience | Smaller conventional hosting ecosystem | Small modern service where Caddy fits team knowledge |
| Nginx/Apache + Uvicorn | ASGI app server path | WebSockets and async protocols | Requires async design discipline | Realtime or WebSocket Django projects |
| Docker Compose | Package dependencies/services as containers | Repeatability and portability | Adds container/network/volume complexity | Teams who already use containers |
| Managed PaaS | Provider runs much of the infrastructure | Less operations burden | Cost and platform constraints | Early products prioritizing speed over server control |

## 4.1 Recommended first serious VPS architecture

For a developer who knows Django and basic Linux, this handbook recommends:

```text
Ubuntu VPS + PostgreSQL + Apache + Gunicorn + systemd + UFW + Certbot
```

Why this path is strong:

- Every component has a focused role.
- It maps to Django’s standard WSGI deployment model. [Django Deployment]
- Apache handles TLS/static files/proxying well.
- Gunicorn keeps Django in a supervised Python process.
- PostgreSQL remains private.
- systemd gives you a real lifecycle manager.
- The stack is easy to migrate to a new server because code, config, database, and media are clearly separated.

## 4.2 When to use mod_wsgi instead

mod_wsgi integrates Django directly into Apache. It is valid and supported by Django’s deployment docs. [Django Deployment]

Choose it when:

- Your team already knows Apache and mod_wsgi.
- Your provider’s environment is built around Apache modules.
- You want one service layer instead of Apache plus Gunicorn.

Avoid mixing it with Gunicorn for the same application URL. Pick one serving path per site.

## 4.3 When ASGI is justified

Use ASGI when you actually need:

- WebSockets / chat / live collaboration.
- Server-sent event streams with long-lived async handling.
- An async ecosystem you understand and have tested.

Do not move a stable WSGI site to ASGI only for performance folklore. Application bottlenecks are often database queries, templates, external APIs, or inefficient code rather than WSGI itself.

<div class="chapter-break"></div>

# Part III - Prepare the project locally

# 5. Your repository is a deployable product, not a folder of code

A new server should be able to build a functioning application from the repository plus deliberately injected secrets and data. That means the repository needs a useful structure.

```text
myapp/
├── manage.py
├── myproject/
│   ├── settings.py
│   ├── urls.py
│   ├── wsgi.py
│   └── asgi.py
├── web/
├── requirements.txt
├── README.md
├── LICENSE
├── .gitignore
├── .env.example
├── deploy/
│   ├── apache/
│   ├── systemd/
│   ├── env/
│   └── scripts/
├── docs/
│   ├── architecture.md
│   ├── operations.md
│   └── runbooks.md
└── .github/
    ├── workflows/
    ├── ISSUE_TEMPLATE/
    └── pull_request_template.md
```

## 5.1 What belongs in Git

Commit:

- Django project/app source code.
- Migrations.
- Templates and static source files.
- Dependency definitions.
- Tests.
- Deployment **templates** and documentation.
- A non-secret environment example.
- CI workflow definitions.

Do not commit:

- `.venv/`.
- Database dumps unless intentionally sanitized example fixtures.
- `db.sqlite3` for a public production app.
- User uploads.
- `staticfiles/` output if it can be regenerated.
- Real `.env` files.
- Private certificate keys.
- API keys, tokens, passwords, or Django `SECRET_KEY`.

## 5.2 A practical `.gitignore`

```gitignore
# Python
__pycache__/
*.py[cod]
*.so
.venv/
venv/

# Django runtime state
*.log
staticfiles/
media/
db.sqlite3

# Environment and secrets
.env
.env.*
!.env.example
*.pem
*.key

# Editor/OS files
.vscode/
.idea/
.DS_Store
```

## 5.3 Dependency management: why it matters

Your laptop may have packages installed that your server does not. Dependencies must therefore be declared.

At minimum:

```bash
python -m pip freeze > requirements.txt
```

For a curated production project, record only direct dependencies in a higher-level file and use a lock/compile process. The rule is simpler than the tooling: **a fresh environment must be able to install exactly what the app needs**.

Example:

```text
Django==<tested-version>
psycopg[binary]==<tested-version>
gunicorn==<tested-version>
```

Do not add a package version just because someone else’s tutorial uses it. Test it locally first.

## 5.4 Local quality gate before every deployment

Run these before you push:

```bash
python manage.py test
python manage.py check
python manage.py check --deploy
python manage.py makemigrations --check --dry-run
```

What each command proves:

| Command | What it tests | What it does not prove |
|---|---|---|
| `test` | Your automated test suite passes in a test database | Real browser behavior or production network setup |
| `check` | Basic Django configuration consistency | Every code path or external service |
| `check --deploy` | Additional production-oriented Django warnings | A full security audit |
| `makemigrations --check --dry-run` | No model change is missing a migration | That the migration is safe on real production data |

## 5.5 Migrations are code that changes data shape

A migration changes database schema/state. It can add a table, add a column, create an index, transform data, or remove a field.

Correct lifecycle:

```text
local model change
-> make migration locally
-> review migration file
-> run local tests
-> commit migration
-> deploy code
-> run migrate on production
```

Do **not** routinely run `makemigrations` on production. Production should apply reviewed migrations, not invent them.

## 5.6 Add a health endpoint early

A health endpoint is a deliberately simple URL used for monitoring and manual checks.

```python
# web/views.py
from django.http import JsonResponse


def health(request):
    return JsonResponse({"status": "ok"})
```

```python
# myproject/urls.py
from django.urls import path
from web.views import health

urlpatterns = [
    path("healthz/", health, name="health"),
]
```

A basic health endpoint proves that DNS, TLS, Apache, Gunicorn, Django routing, and response rendering work. A database-aware health endpoint can test the database too, but should be designed carefully so it does not create unnecessary load or expose internal details.

<div class="chapter-break"></div>

# 6. Make Django production-aware

Django does not know whether it is local, staging, or production unless you configure it. The safest pattern is:

- Code contains defaults and parsing logic.
- A local `.env` can exist only on a developer machine.
- Production settings come from a protected environment file loaded by systemd.

## 6.1 The settings that matter most

| Setting | What it controls | Why it matters in production |
|---|---|---|
| `SECRET_KEY` | Cryptographic signing | Must be secret and stable; rotate if exposed |
| `DEBUG` | Detailed error pages/debug behavior | Must be `False` publicly |
| `ALLOWED_HOSTS` | Valid host headers | Prevents unintended host handling |
| `CSRF_TRUSTED_ORIGINS` | Trusted HTTPS origins for CSRF validation | Required for secure cross-origin/proxy patterns |
| `DATABASES` | Database connection | Must use protected credentials |
| `STATIC_ROOT` | Destination of `collectstatic` | Apache serves from here |
| `MEDIA_ROOT` | User-upload directory | Requires backup and permission planning |
| `SECURE_SSL_REDIRECT` | Redirect HTTP to HTTPS | Use once HTTPS/proxy handling is correct |
| secure cookies | Force cookies over HTTPS | Prevents cookie transport over plain HTTP |

Django’s deployment checklist recommends running `manage.py check --deploy` and reviewing production-only settings before release. [Django Checklist]

## 6.2 Example production settings pattern

This is intentionally explicit instead of using hidden convenience packages:

```python
# myproject/settings.py
import os
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def env_bool(name: str, default: bool = False) -> bool:
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name: str, default: str = "") -> list[str]:
    raw = os.environ.get(name, default)
    return [item.strip() for item in raw.split(",") if item.strip()]


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
        "CONN_MAX_AGE": int(os.environ.get("POSTGRES_CONN_MAX_AGE", "60")),
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

# Only needed when a trusted reverse proxy terminates HTTPS and sets this header.
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

### What this code means

- `os.environ[...]` deliberately fails if a mandatory secret is missing. Failing early is better than silently booting with unsafe fallback credentials.
- `env_bool` prevents the common bug where the non-empty string `"False"` is treated as truthy in Python.
- `env_list` turns comma-separated values into a Python list.
- `CONN_MAX_AGE` allows persistent database connections for a limited period; tune later rather than treating it as a magic performance switch.
- `STATIC_ROOT` is not where you write frontend source files. It is the collected output Apache serves.
- `SECURE_PROXY_SSL_HEADER` is valid only when Apache controls and sets `X-Forwarded-Proto`. Do not trust this header from arbitrary clients.

## 6.3 Example `.env.example`

```dotenv
# Copy to a protected server location; never commit the real file.
DJANGO_SECRET_KEY='replace-with-a-long-random-value'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=example.com,www.example.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://example.com,https://www.example.com
DJANGO_USE_HTTPS=True

POSTGRES_DB=myapp
POSTGRES_USER=myapp_db
POSTGRES_PASSWORD='replace-with-a-unique-password'
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_CONN_MAX_AGE=60

DEFAULT_FROM_EMAIL='My App <noreply@example.com>'
SERVER_EMAIL='My App Errors <errors@example.com>'
```

## 6.4 Static files and media are different

| Type | Examples | Where it originates | Can it be rebuilt? | Backup it? |
|---|---|---|---|---|
| Static files | CSS, JS, icons, app images | Your source tree/dependencies | Yes: `collectstatic` | Usually no, if source is committed |
| Media files | user avatars, uploads, documents | User input at runtime | No | Yes |

Confusing these creates missing CSS, accidental data loss, or permissions problems.

<div class="chapter-break"></div>

# Part IV - Publish a project responsibly as open source

# 7. Public code is not automatically open source

A repository made public on GitHub lets people view the code, but without a license it does not clearly grant reuse rights. A real open-source project has an explicit license and documentation that tells people what they may do.

## 7.1 Open-source publication checklist

| File / feature | Why it exists | Minimum content |
|---|---|---|
| `README.md` | Explains what the project is and how to start | purpose, screenshots, prerequisites, install, run, test, deploy overview |
| `LICENSE` | Defines legal permission to use/modify/distribute | chosen full license text |
| `CONTRIBUTING.md` | Makes contributions predictable | setup, tests, style, branch/PR expectations |
| `CODE_OF_CONDUCT.md` | Defines community behavior expectations | adopted code of conduct and reporting path |
| `SECURITY.md` | Gives a private vulnerability reporting route | supported versions, contact, disclosure expectations |
| `CHANGELOG.md` | Records user-facing changes | release date/version/fixes/features |
| `.env.example` | Shows required configuration without leaking secrets | variable names and safe placeholders |
| issue templates | Improve bug reports and feature requests | reproduction steps, expected/actual behavior, environment |
| pull request template | Makes review easier | summary, tests, migration/security notes |
| CI workflow | Validates code consistently | tests/checks on push and pull request |

GitHub’s community profile checks for several community-health files, including README, license, code of conduct, and contribution guidelines. [GitHub Community]

## 7.2 License choice, explained simply

This is not legal advice, but these are common practical choices:

| License | Basic intent | Choose it when | Main trade-off |
|---|---|---|---|
| MIT | Very permissive | You want simple broad reuse | Others can use it in proprietary products |
| Apache-2.0 | Permissive with explicit patent terms | You want a business-friendly permissive license with patent language | Slightly longer/more formal |
| GPLv3 | Strong copyleft for distributed derivatives | You want distributed modified versions to remain GPL | Some companies avoid GPL dependencies |
| AGPLv3 | Network copyleft | You want hosted modified versions to provide source to users | Strongest adoption restriction in this table |

Do not copy a random license header from another project. Choose deliberately. When in doubt for a small learning/project repository, MIT or Apache-2.0 are common permissive choices; consult legal advice for commercial or sensitive projects.

## 7.3 README structure that actually helps people

```markdown
# Project Name

One sentence: what it does and who it is for.

## Features
- ...

## Quick start
- prerequisites
- clone
- virtualenv
- install dependencies
- create local environment file
- migrate
- run server

## Configuration
List variables from `.env.example`; do not publish values.

## Testing
Commands for unit/integration/browser tests.

## Production deployment
Point to `docs/deployment.md`; do not hide deployment knowledge in chat history.

## Contributing
Link to `CONTRIBUTING.md`.

## Security
Link to `SECURITY.md`.

## License
State the selected license.
```

## 7.4 Security policy

A `SECURITY.md` tells researchers how to report a problem privately instead of opening a public issue with exploit details.

```markdown
# Security Policy

## Supported versions
Only the latest release on the `main` branch is currently supported.

## Reporting a vulnerability
Please do not open a public issue for a suspected vulnerability.
Email security@example.com with:
- affected version or commit
- reproduction steps
- impact
- suggested mitigation, if known

We aim to acknowledge reports within 7 days and provide a status update within 14 days.
```

GitHub supports repository security policies and private vulnerability reporting/advisories for public projects. [GitHub Security Policy]

## 7.5 Secret safety for public repositories

Before publishing a repository:

```bash
# Search current tracked files for suspicious names/values.
git grep -nEi 'secret|password|token|api[_-]?key|private[_-]?key' || true

# Confirm ignored secret files are not tracked.
git ls-files | grep -E '(^|/)(\.env|.*\.pem|.*\.key)$' || true
```

Also inspect Git history. Removing a secret from the latest file does not remove it from earlier commits. A leaked credential should be rotated, even if you later delete the commit or repository. GitHub’s secret scanning and push protection are useful additional controls, but they do not replace careful handling. [GitHub Secret Safety]

## 7.6 Release tags and Semantic Versioning

A version such as `v0.2.0-beta.3` identifies a specific code snapshot. The `beta.3` suffix signals that the future `0.2.0` release remains unstable and is being tested.

Basic convention:

```text
v0.2.0-beta.1  first testing snapshot
v0.2.0-beta.2  same future version, later beta fixes
v0.2.0         stable release
v0.2.1         compatible bug-fix release
v0.3.0         compatible new feature release while major version is 0
v1.0.0         first declared stable public API/release
```

A pre-release has lower precedence than the corresponding final release under Semantic Versioning. [SemVer]

Do not move old tags just because you created a newer release. A tag should remain an honest record of the code that was released at that time.

<div class="chapter-break"></div>

# Part V - Build the server from zero

# 8. Establish names and target layout

Choose names once and use them consistently. This handbook uses placeholders:

```text
APP_NAME       = myapp
PROJECT_NAME   = myproject
DOMAIN         = example.com
WWW_DOMAIN     = www.example.com
DEPLOY_USER    = deploy
APP_USER       = myapp
DB_NAME        = myapp
DB_USER        = myapp_db
GUNICORN_PORT  = 8001
REPO_URL       = https://github.com/your-account/your-repository.git
```

Target filesystem layout:

```text
/srv/myapp/
├── app/            # Git checkout, editable by deploy user
├── venv/           # Python virtual environment
├── staticfiles/    # generated by collectstatic
└── media/          # persistent user uploads

/etc/myapp/
└── myapp.env       # real environment variables/secrets; never in Git

/var/backups/myapp/
└── postgresql/     # local DB archives

/etc/systemd/system/
└── myapp-gunicorn.service

/etc/apache2/sites-available/
└── myapp.conf
```

## 8.1 Two Linux identities, two responsibilities

| User | Purpose | Should have SSH login? | Should run Gunicorn? | Should have broad sudo? |
|---|---|---:|---:|---:|
| `deploy` | Human operator who pulls approved code | Yes | No | Limited/admin only |
| `myapp` | Noninteractive service account | No | Yes | No |

Why separate them:

- A web process should not have your human deployment privileges.
- A human account should not automatically become the application runtime identity.
- File permissions become clearer: deploy writes code; the app reads code; only the app writes runtime media.

# 9. First login and safe package baseline

Start as root only long enough to create a non-root admin account. Keep one root/recovery path through your provider console in case you make an SSH mistake.

```bash
apt update
apt upgrade
apt install -y sudo curl git ca-certificates

adduser deploy
usermod -aG sudo deploy
```

**What these do:**

- `apt update` refreshes package metadata.
- `apt upgrade` applies available updates to installed packages.
- `sudo` allows controlled elevation from the deploy account.
- `git` is the code transport mechanism.
- `ca-certificates` enables HTTPS certificate verification for tools such as Git and package managers.

Before disabling root/password login, verify you can open a **second** terminal and authenticate as `deploy` with a working SSH key. Never lock down the only active SSH session first.

## 9.1 SSH keys and hardening

A public key is placed on the server; the matching private key remains on your computer. This is stronger and more manageable than ordinary password login when configured correctly.

After verifying key login in a second session, create a hardening drop-in:

```bash
sudo tee /etc/ssh/sshd_config.d/99-myapp-hardening.conf >/dev/null <<'EOF'
PermitRootLogin no
PasswordAuthentication no
KbdInteractiveAuthentication no
PubkeyAuthentication yes
AllowUsers deploy
EOF

sudo sshd -t
sudo systemctl reload ssh
```

**Line-by-line meaning:**

- `PermitRootLogin no`: root cannot log in over SSH.
- `PasswordAuthentication no`: prevents password guessing over SSH.
- `KbdInteractiveAuthentication no`: disables another interactive password pathway.
- `PubkeyAuthentication yes`: permits SSH keys.
- `AllowUsers deploy`: only the listed account may use SSH. Add every genuinely required SSH account before enabling it.

> **Safety rule:** Do not apply this until key login is proven from another terminal. `sshd -t` validates syntax before you reload the service.

## 9.2 Install runtime packages

```bash
sudo apt update
sudo apt install -y \
  python3 python3-venv python3-pip python3-dev \
  postgresql postgresql-contrib libpq-dev \
  apache2 certbot python3-certbot-apache \
  ufw fail2ban unattended-upgrades
```

Why these packages exist:

| Package | Purpose |
|---|---|
| `python3` | Python interpreter |
| `python3-venv` | isolated Python environment support |
| `python3-pip` | Python package installer |
| `python3-dev` / `libpq-dev` | build headers for some Python/database dependencies |
| `postgresql` | database server |
| `postgresql-contrib` | useful PostgreSQL extensions/tools |
| `apache2` | public web server and reverse proxy |
| `certbot` / Apache plugin | TLS certificate issuance and renewal integration |
| `ufw` | simple host firewall management |
| `fail2ban` | temporary bans after repeated failed authentication patterns |
| `unattended-upgrades` | optional automated security update support |

<div class="chapter-break"></div>

# 10. Create service users and directories

Create the noninteractive application identity:

```bash
sudo adduser --system --group --home /srv/myapp --shell /usr/sbin/nologin myapp
```

Meaning:

- `--system`: create a system account, not a normal human account.
- `--group`: create a matching Linux group.
- `--home`: records a logical app home.
- `--shell /usr/sbin/nologin`: prevents interactive shell login.

Create directories:

```bash
sudo install -d -o deploy -g myapp -m 2750 /srv/myapp
sudo install -d -o deploy -g myapp -m 2750 /srv/myapp/app
sudo install -d -o deploy -g myapp -m 2750 /srv/myapp/venv
sudo install -d -o myapp -g www-data -m 2755 /srv/myapp/staticfiles
sudo install -d -o myapp -g www-data -m 2750 /srv/myapp/media
sudo install -d -o root -g myapp -m 0750 /etc/myapp
sudo install -d -o postgres -g postgres -m 0700 /var/backups/myapp/postgresql
```

## 10.1 Read the permission numbers

Linux permission modes use three groups: owner, group, everyone else.

```text
7 = read + write + execute
5 = read + execute
4 = read
0 = no access
```

Directories need the execute bit to be entered/traversed. `2750` also sets the setgid bit, helping new files inherit the directory group. Permissions are not a decoration: they decide whether Apache can read assets, whether Gunicorn can write media, and whether another local account can read secrets.

**Important:** exact ownership must fit your app’s behavior. Do not use `chmod -R 777` as a “fix.” It hides the ownership model and creates unnecessary write access.

# 11. Clone code and create the virtual environment

Run Git and Python environment work as `deploy`, not root:

```bash
sudo -u deploy -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp

git clone https://github.com/your-account/your-repository.git app
python3 -m venv venv
/srv/myapp/venv/bin/python -m pip install --upgrade pip
/srv/myapp/venv/bin/pip install -r app/requirements.txt
'
```

What `set -Eeuo pipefail` means:

- `-e`: stop when a command fails.
- `-E`: preserve error traps in functions/subshells if used.
- `-u`: treat an unset variable as an error.
- `pipefail`: fail a pipeline when any command in it fails, not only the last command.

This makes a deployment script fail loudly instead of continuing after a missing directory, failed install, or typo.

Ensure the service account can read the code and virtual environment:

```bash
sudo chown -R deploy:myapp /srv/myapp/app /srv/myapp/venv
sudo chmod -R g+rX /srv/myapp/app /srv/myapp/venv
```

# 12. Create PostgreSQL role and database

PostgreSQL has its own security identities. Create a restricted role for the app, then make that role own only its application database.

```bash
sudo -u postgres createuser \
  --pwprompt \
  --no-createdb \
  --no-createrole \
  --no-superuser \
  myapp_db

sudo -u postgres createdb --owner=myapp_db myapp
```

Meaning:

- `--pwprompt`: asks for a password without putting it in shell history.
- `--no-createdb`, `--no-createrole`, `--no-superuser`: app database credentials cannot create databases, create roles, or become a superuser.
- `createdb --owner`: ensures the app database role owns its own database objects.

Check it:

```bash
sudo -u postgres psql -c '\du'
sudo -u postgres psql -c '\l'
```

Do not expose PostgreSQL port `5432` publicly for a single-server app. Django connects through `127.0.0.1`; browsers never need database access.

# 13. Create the protected environment file

```bash
sudo tee /etc/myapp/myapp.env >/dev/null <<'EOF'
DJANGO_SECRET_KEY='replace-with-a-generated-secret'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=example.com,www.example.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://example.com,https://www.example.com
DJANGO_USE_HTTPS=True

POSTGRES_DB=myapp
POSTGRES_USER=myapp_db
POSTGRES_PASSWORD='replace-with-the-db-role-password'
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
POSTGRES_CONN_MAX_AGE=60
EOF

sudo chown root:myapp /etc/myapp/myapp.env
sudo chmod 640 /etc/myapp/myapp.env
```

Why root owns the file:

- The app service needs to **read** it.
- The compromised web process should not be able to edit it.
- Human deploy users should use controlled `sudo` to change secrets, not accidentally edit them as part of normal Git work.

Generate a Django secret locally or on the server without displaying it in chat/logs:

```bash
/srv/myapp/venv/bin/python -c 'from django.core.management.utils import get_random_secret_key; print(get_random_secret_key())'
```

Treat any secret pasted into a public issue, chat, commit, screenshot, or shell history as potentially exposed; rotate it.

<div class="chapter-break"></div>

# Part VI - Turn the project into a service

# 14. Test Django before wiring Apache

Run maintenance commands as the **application service user** so you validate the same permissions and environment model Gunicorn will use.

```bash
sudo -u myapp -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app
set -a
. /etc/myapp/myapp.env
set +a

/srv/myapp/venv/bin/python manage.py check --deploy
/srv/myapp/venv/bin/python manage.py migrate --noinput
/srv/myapp/venv/bin/python manage.py collectstatic --noinput
'
```

Why source the environment here? Your interactive shell does not automatically know the variables systemd will inject into Gunicorn. Activating a virtual environment only changes Python/PATH; it does not load secrets or database settings.

**Do not run Django commands as root by default.** If root runs `manage.py`, PostgreSQL or settings may infer the wrong identity/environment and fail in misleading ways.

# 15. Gunicorn service: build it and understand it

Create `/etc/systemd/system/myapp-gunicorn.service`:

```ini
[Unit]
Description=Gunicorn application server for myapp
After=network.target

[Service]
User=myapp
Group=myapp
WorkingDirectory=/srv/myapp/app
EnvironmentFile=/etc/myapp/myapp.env
Environment="PATH=/srv/myapp/venv/bin"

ExecStart=/srv/myapp/venv/bin/gunicorn \
  --workers 3 \
  --bind 127.0.0.1:8001 \
  --access-logfile - \
  --error-logfile - \
  myproject.wsgi:application

Restart=on-failure
RestartSec=5
TimeoutStopSec=30

[Install]
WantedBy=multi-user.target
```

Enable and start it:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now myapp-gunicorn.service
sudo systemctl --no-pager --full status myapp-gunicorn.service
```

## 15.1 Every important Gunicorn/systemd line explained

| Line | Meaning | Why it matters |
|---|---|---|
| `[Unit]` | service metadata/dependencies | lets systemd order startup |
| `After=network.target` | start after basic networking | avoids starting too early during boot |
| `User=myapp` / `Group=myapp` | run as restricted account | web code does not run as root |
| `WorkingDirectory` | base directory for relative paths | Django/Gunicorn import paths work predictably |
| `EnvironmentFile` | load protected settings/secrets | keeps credentials out of code and unit text |
| `PATH=...` | use virtualenv binaries | correct Gunicorn/Python packages are used |
| `ExecStart` | exact process systemd starts | this is the application runtime contract |
| `--workers 3` | run three worker processes | basic concurrency; tune from measurement |
| `--bind 127.0.0.1:8001` | listen only on local loopback | prevents direct public access to Gunicorn |
| `--access-logfile -` | send access logs to stdout/journal | use `journalctl` instead of ad-hoc files |
| `--error-logfile -` | send errors to stderr/journal | central debugging path |
| `Restart=on-failure` | restart after unexpected exit | app comes back after crashes |
| `WantedBy=multi-user.target` | enable at normal server boot | app returns after reboot |

## 15.2 Test Gunicorn directly, but only locally

```bash
curl -I http://127.0.0.1:8001/healthz/
```

A good result proves Gunicorn imported Django and Django answered locally. It does **not** prove Apache, TLS, DNS, or the firewall.

## 15.3 Optional systemd hardening after the app already works

Add gradually and test after each change:

```ini
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=full
ReadWritePaths=/srv/myapp/media
```

These can reduce the process’s ability to change the host filesystem. They are useful, but settings vary by app. Do not blindly add them and assume success; verify uploads, temporary files, logs, and background work afterward.

# 16. Apache: the public front door

Enable the modules used by the guided architecture:

```bash
sudo a2enmod proxy proxy_http headers rewrite ssl
sudo systemctl restart apache2
```

Create an initial HTTP virtual host at `/etc/apache2/sites-available/myapp.conf`:

```apache
<VirtualHost *:80>
    ServerName example.com
    ServerAlias www.example.com

    ErrorLog ${APACHE_LOG_DIR}/myapp-http-error.log
    CustomLog ${APACHE_LOG_DIR}/myapp-http-access.log combined
</VirtualHost>
```

Enable it:

```bash
sudo a2ensite myapp.conf
sudo a2dissite 000-default.conf
sudo apache2ctl configtest
sudo systemctl reload apache2
```

Then obtain a certificate using Certbot’s Apache integration:

```bash
sudo certbot --apache -d example.com -d www.example.com
```

Certbot may offer to redirect HTTP to HTTPS. That is usually appropriate after you confirm both domain names are correct.

## 16.1 Final Apache HTTPS virtual host, annotated

After certificate issuance, the final SSL virtual host should conceptually look like this:

```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    # Keep the original public Host header for Django.
    ProxyPreserveHost On

    # Tell Django that the original client connection used HTTPS.
    RequestHeader set X-Forwarded-Proto "https"

    # Static and media must be served directly, before the catch-all proxy.
    ProxyPass /static/ !
    Alias /static/ /srv/myapp/staticfiles/
    <Directory /srv/myapp/staticfiles>
        Require all granted
    </Directory>

    ProxyPass /media/ !
    Alias /media/ /srv/myapp/media/
    <Directory /srv/myapp/media>
        Require all granted
    </Directory>

    # Everything else is dynamic and goes to Gunicorn on loopback.
    ProxyPass / http://127.0.0.1:8001/
    ProxyPassReverse / http://127.0.0.1:8001/

    # Safe baseline response headers. Test framing/CSP needs per application.
    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set X-Frame-Options "DENY"

    ErrorLog ${APACHE_LOG_DIR}/myapp-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/myapp-ssl-access.log combined
</VirtualHost>
</IfModule>
```

## 16.2 Why directive order matters

Apache processes `ProxyPass` rules in order. The exceptions for `/static/` and `/media/` must appear before the catch-all `/` proxy. Otherwise Apache forwards static-file URLs to Gunicorn instead of serving them from disk.

## 16.3 Why `ProxyPreserveHost On` matters

Django uses host information for `ALLOWED_HOSTS`, redirects, and URL construction. Preserving the original host avoids the backend seeing only `127.0.0.1:8001`.

## 16.4 Why `X-Forwarded-Proto` matters

Apache terminates TLS, then proxies plain HTTP to Gunicorn over loopback. Without a trusted forwarded-protocol header, Django sees the backend connection as HTTP even though the browser used HTTPS. That can cause redirect loops, secure-cookie problems, or CSRF behavior that seems inconsistent.

The pair is deliberate:

```apache
RequestHeader set X-Forwarded-Proto "https"
```

```python
SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
```

Only configure this pair when **your own trusted proxy** sets the header. Never trust arbitrary client-provided proxy headers.

## 16.5 Apache verification

```bash
sudo apache2ctl configtest
sudo systemctl reload apache2
sudo systemctl --no-pager --full status apache2

curl -I http://127.0.0.1/
curl -kI --resolve example.com:443:127.0.0.1 https://example.com/healthz/
```

Expected pattern:

- HTTP returns `301` or `308` redirect to HTTPS.
- HTTPS returns `200` from your Django health endpoint.

<div class="chapter-break"></div>

# 17. HTTPS and certificate renewal

## 17.1 What Certbot needs before it can succeed

- DNS for the domain points to the server’s public IP.
- Port 80 is reachable from the public internet for normal HTTP validation.
- Apache has a matching `ServerName`/`ServerAlias` virtual host.
- No proxy/CDN configuration blocks the validation path unexpectedly.

## 17.2 Verify automatic renewal

```bash
sudo certbot renew --dry-run
systemctl list-timers --all | grep -i certbot || true
```

Certbot considers certificates ready for renewal when they are within part of their lifetime window; do not wait until expiry to test. [Certbot]

## 17.3 HSTS: useful but intentionally deferred

HTTP Strict Transport Security tells browsers to prefer HTTPS for a domain for a period of time. It is powerful because a wrong setting can make a domain unreachable until the browser’s policy expires.

Enable HSTS only after:

- HTTPS is stable.
- Every hostname you include is HTTPS-capable.
- You understand the consequences of `includeSubDomains`.
- You have tested redirect behavior and certificate renewal.

A cautious first value is often short-lived during testing, then increased deliberately. Do not copy `preload` settings casually.

# 18. UFW, SSH, Fail2Ban, and updates

## 18.1 The correct public port model

For the guided architecture, external users need only:

| Port | Protocol | Reason |
|---:|---|---|
| 22 | TCP | SSH administration |
| 80 | TCP | HTTP redirect and ACME validation |
| 443 | TCP | HTTPS application traffic |

Do **not** expose:

| Port | Why it stays private |
|---:|---|
| 5432 | PostgreSQL is for the app/server, not browsers |
| 8001 | Gunicorn is behind Apache |
| 8000 | Django development server is not a public service |

## 18.2 Safe UFW baseline

Keep your current SSH session open while changing firewall policy.

```bash
sudo ufw allow OpenSSH comment 'SSH administration'
sudo ufw allow 80/tcp comment 'HTTP redirect and ACME validation'
sudo ufw allow 443/tcp comment 'HTTPS application'

sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status verbose
```

Why these defaults:

- **Deny incoming:** unsolicited inbound connections are rejected unless explicitly allowed.
- **Allow outgoing:** server components can fetch OS updates, packages, certificate renewals, and external APIs. Restrict outbound traffic later only when you understand every dependency.

UFW is Ubuntu’s simple host-firewall interface over the kernel packet-filtering system. [Ubuntu Firewall]

## 18.3 Fail2Ban

Fail2Ban reads logs and can temporarily ban addresses that repeatedly fail authentication patterns, such as SSH password attempts.

Example SSH jail:

```ini
# /etc/fail2ban/jail.d/sshd.local
[sshd]
enabled = true
maxretry = 5
findtime = 10m
bantime = 1h
```

Then:

```bash
sudo systemctl enable --now fail2ban
sudo fail2ban-client status sshd
```

Fail2Ban is not a substitute for SSH keys and a firewall. It is a rate-limiting consequence layer.

## 18.4 Operating system updates

Apply updates regularly. For many small VPSs, automatic security updates are worth enabling after you understand the provider/organization’s maintenance policy:

```bash
sudo dpkg-reconfigure --priority=low unattended-upgrades
```

Still schedule manual maintenance: automatic updates do not replace checking service health, disk space, renewal, backups, or application dependencies.

## 18.5 Security baseline versus security theater

High-value controls for a small Django VPS:

- SSH keys and no SSH root/password login after verified access.
- Separate deploy and app users.
- Protected environment file.
- `DEBUG=False`.
- Private database and Gunicorn ports.
- UFW with only 22/80/443 inbound.
- Updates and Fail2Ban.
- HTTPS plus renewal test.
- Backups plus restore drill.
- Least privilege and readable logs.

Lower-value or misleading habits:

- Changing SSH port alone and calling the server secure.
- Randomly adding headers without testing their application effect.
- Exposing PostgreSQL “because it is password-protected.”
- `chmod -R 777`.
- Disabling CSRF to “fix” a form error.
- Treating a same-server backup as sufficient disaster recovery.

<div class="chapter-break"></div>

# Part VII - Day-2 operations

# 19. Normal deployment workflow

The live server should **pull approved code**. It should not become the primary place where code is authored and committed.

## 19.1 Before deployment

Local computer:

```bash
python manage.py test
python manage.py check --deploy
python manage.py makemigrations --check --dry-run
git status --short --branch
git push origin main
```

## 19.2 Inspect, then pull

On the server, as `deploy`:

```bash
sudo -u deploy -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app

git status --short --branch
git fetch origin
git log --oneline HEAD..origin/main
'
```

Why inspect first:

- A dirty server working tree can block a pull or hide manual drift.
- Seeing incoming commits helps decide whether you need migrations, static collection, dependency installation, or a simple restart.
- `git pull --ff-only` avoids creating an automatic merge commit on production. It either advances cleanly or stops.

## 19.3 Standard deploy runbook

```bash
sudo -u deploy -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app

git pull --ff-only origin main
/srv/myapp/venv/bin/pip install -r requirements.txt
'

sudo -u myapp -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app
set -a
. /etc/myapp/myapp.env
set +a

/srv/myapp/venv/bin/python manage.py check
/srv/myapp/venv/bin/python manage.py migrate --noinput
/srv/myapp/venv/bin/python manage.py collectstatic --noinput
'

sudo systemctl restart myapp-gunicorn
sudo apache2ctl configtest
sudo systemctl reload apache2
```

This is a safe generalized runbook, but it is useful to understand when each item is needed:

| Change type | Must run | Why |
|---|---|---|
| Python/template code | restart Gunicorn | workers have old code in memory |
| New migration files | `migrate` | apply reviewed schema changes |
| CSS/JS/static assets | `collectstatic` | copy collected output for Apache |
| New Python dependency | `pip install -r requirements.txt` + restart Gunicorn | virtualenv must contain package |
| Apache configuration | `apache2ctl configtest` + reload Apache | validate and apply web-server rules |
| Environment file | restart Gunicorn | service must reload injected variables |
| Only documentation | Git pull only | runtime behavior unchanged |

Running `collectstatic` and `migrate` repeatedly is usually safe when configured correctly, but do not turn them into rituals you do not understand. Know why you are invoking each command.

## 19.4 Verification after deploy

```bash
sudo systemctl --no-pager --full status myapp-gunicorn
sudo systemctl --no-pager --full status apache2
curl -fsS https://example.com/healthz/
sudo -u deploy -H bash -lc 'cd /srv/myapp/app && git log -1 --oneline'
```

Then test a critical user path manually:

```text
home -> sign up/login -> create object -> admin workflow -> public detail page -> logout
```

## 19.5 Rollback philosophy

A rollback should mean “return code to a known good Git commit/tag,” not “randomly edit files on the server.”

Safer approaches:

- Revert the bad commit locally, test, push, then deploy.
- Deploy a known good tag/commit after carefully considering migrations.
- Restore database data only when the data state itself is bad; code rollback and database rollback are separate decisions.

Migrations complicate rollback. A schema/data migration may not be safely reversible. Plan and test important migrations before production.

# 20. Backups and restoration

A backup you have never restored is only a hypothesis.

## 20.1 PostgreSQL custom-format dump

```bash
sudo -u postgres pg_dump \
  --format=custom \
  --no-owner \
  --no-privileges \
  --file=/var/backups/myapp/postgresql/myapp-$(date -u +%Y-%m-%dT%H%M%SZ).dump \
  myapp
```

Why custom format:

- It works with `pg_restore`.
- You can inspect it, restore selected objects, and often restore in parallel.
- PostgreSQL documents custom/directory archive formats as flexible dump/restore mechanisms. [PostgreSQL Backup]

Verify immediately:

```bash
sudo -u postgres pg_restore --list /var/backups/myapp/postgresql/myapp-YYYY-MM-DDTHHMMSSZ.dump >/dev/null
```

## 20.2 What to back up

| Asset | Backup method |
|---|---|
| PostgreSQL database | `pg_dump` archive, verified with `pg_restore --list` |
| Media uploads | rsync/object storage/archive snapshot |
| Environment file | encrypted secure copy, not Git |
| Apache/systemd config | source-controlled templates plus secure server config backup |
| DNS records | documented export/screenshot/runbook |
| Git code | remote repository and tags |

## 20.3 Off-server copies are mandatory for real recovery

A disk failure, provider account problem, accidental server deletion, or ransomware event can remove the application and its same-server backups together.

Use at least one off-server destination:

- encrypted cloud storage,
- another server,
- a secure local disk,
- object storage.

Apply the **3-2-1 idea** where practical: three copies, two media/location types, one copy off-site.

## 20.4 Restore drill into a separate database

Never start a learning restore by overwriting production.

```bash
sudo -u postgres createdb --owner=myapp_db myapp_restore_test
sudo -u postgres pg_restore \
  --no-owner \
  --no-privileges \
  --dbname=myapp_restore_test \
  /var/backups/myapp/postgresql/myapp-YYYY-MM-DDTHHMMSSZ.dump
```

Then inspect the test database and drop it when finished:

```bash
sudo -u postgres dropdb myapp_restore_test
```

## 20.5 Nightly systemd timer concept

A timer is systemd’s scheduled-job mechanism. It starts a service unit at a defined time and can catch up after missed runs when configured persistently.

The correct backup job pattern is:

```text
systemd timer -> one-shot backup service -> pg_dump custom archive -> verify archive -> retention cleanup -> off-server copy
```

Do not rely on a timer you have never manually triggered and checked.

# 21. Logs and monitoring

## 21.1 Where to look first

| Layer | Command / location |
|---|---|
| Gunicorn/Django service | `sudo journalctl -u myapp-gunicorn -f` |
| Gunicorn recent errors | `sudo journalctl -u myapp-gunicorn -n 200 --no-pager` |
| Apache service | `sudo systemctl status apache2` |
| Apache app access log | `/var/log/apache2/myapp-ssl-access.log` |
| Apache app error log | `/var/log/apache2/myapp-ssl-error.log` |
| PostgreSQL service | `sudo systemctl status postgresql` |
| PostgreSQL logs | distribution/version-specific journal/log location |
| Firewall | `sudo ufw status verbose` and configured logs |

## 21.2 Debugging sequence for HTTP 500

1. Reproduce the exact user action once.
2. Follow Gunicorn journal logs.
3. Read the traceback, not just the final HTTP status.
4. Identify source file/line and failing dependency/data condition.
5. Fix locally and add a regression test.
6. Deploy with the standard runbook.

Do not set `DEBUG=True` on production just to get a traceback in a browser. That can leak paths, settings, and sensitive context.

## 21.3 Uptime monitoring

An external uptime monitor should request a simple route such as:

```text
https://example.com/healthz/
```

It catches DNS, certificate, firewall, Apache, Gunicorn, and broad application outages from outside the server.

Error tracking tools such as Sentry complement uptime monitoring: they capture application exceptions with context. They do not replace tests or backups.

<div class="chapter-break"></div>

# Part VIII - Test before users discover bugs

# 22. The testing ladder

No single tool can prove a whole website has no bugs. Build layers.

| Layer | Example | Catches |
|---|---|---|
| Unit tests | model method, utility function | small logic errors |
| Django integration tests | URL/view/form/database assertion | app-layer behavior |
| Migration tests/checks | migration exists and applies | schema drift |
| Browser end-to-end tests | Playwright signs up, posts, clicks links | broken user flows, JavaScript, redirects |
| Staging smoke tests | feature branch in isolated environment | production-like integration issues |
| Production smoke test | health endpoint + critical manual flow | deploy/config regressions |
| Monitoring | uptime/error tracking | real failures after release |

## 22.1 Regression tests are operational memory

When you fix a real bug, add a test that would fail if the bug returns.

Examples from a blog-like Django project:

- Publishing sets `pub_date`.
- A published post’s generated URL returns HTTP 200.
- Draft cards link to edit rather than a nonpublic detail route.
- A post near midnight uses the project’s local calendar date consistently.
- Slug generation produces a unique stable URL.

The value is not only correctness today. The test explains why a line of code exists months later.

## 22.2 Staging is not production with another name

A proper staging environment should have:

- a separate hostname such as `staging.example.com`,
- a separate code checkout/branch,
- a separate database,
- separate media/static paths,
- separate secrets,
- restricted email behavior (test inbox or disabled sending),
- its own Gunicorn systemd service and Apache virtual host.

Never test destructive migrations, real email sends, or incomplete features against production data just because the server is convenient.

## 22.3 CI with GitHub Actions

Continuous integration runs validation automatically for pushes and pull requests. GitHub Actions can run Python tests and checks from a workflow in the repository. [GitHub Actions]

Minimal example:

```yaml
# .github/workflows/ci.yml
name: Django CI

on:
  push:
  pull_request:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"
      - run: python -m pip install --upgrade pip
      - run: pip install -r requirements.txt
      - run: python manage.py test
      - run: python manage.py check
```

Real projects may need test-only environment variables and a PostgreSQL service. Start with a workflow that actually passes and improve it deliberately.

# 23. The migration path to larger systems

A single VPS is a good starting architecture for many small/medium applications. Scale when evidence demands it.

Possible next stages:

```text
Stage 1: one VPS
Apache + Gunicorn + Django + PostgreSQL

Stage 2: separate backup destination and monitoring

Stage 3: staging environment

Stage 4: managed PostgreSQL or separate database server

Stage 5: multiple application servers behind a load balancer

Stage 6: object storage/CDN for static/media

Stage 7: queue workers/cache/search service as actual workload requires
```

Do not add Redis, Celery, Kubernetes, multiple databases, or a CDN merely because a popular architecture diagram includes them. Every component adds configuration, failure modes, upgrade work, and monitoring needs.

<div class="chapter-break"></div>

# Part IX - Reference configurations

# 24. A complete minimal reference set

## 24.1 `requirements.txt`

```text
Django==<tested-version>
psycopg[binary]==<tested-version>
gunicorn==<tested-version>
```

## 24.2 `.env.example`

```dotenv
DJANGO_SECRET_KEY='replace-me'
DJANGO_DEBUG=False
DJANGO_ALLOWED_HOSTS=example.com,www.example.com
DJANGO_CSRF_TRUSTED_ORIGINS=https://example.com,https://www.example.com
DJANGO_USE_HTTPS=True
POSTGRES_DB=myapp
POSTGRES_USER=myapp_db
POSTGRES_PASSWORD='replace-me'
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

## 24.3 systemd Gunicorn unit

```ini
[Unit]
Description=Gunicorn application server for myapp
After=network.target

[Service]
User=myapp
Group=myapp
WorkingDirectory=/srv/myapp/app
EnvironmentFile=/etc/myapp/myapp.env
Environment="PATH=/srv/myapp/venv/bin"
ExecStart=/srv/myapp/venv/bin/gunicorn --workers 3 --bind 127.0.0.1:8001 --access-logfile - --error-logfile - myproject.wsgi:application
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
```

## 24.4 Apache HTTPS virtual host

```apache
<IfModule mod_ssl.c>
<VirtualHost *:443>
    ServerName example.com
    ServerAlias www.example.com

    SSLEngine on
    SSLCertificateFile /etc/letsencrypt/live/example.com/fullchain.pem
    SSLCertificateKeyFile /etc/letsencrypt/live/example.com/privkey.pem

    ProxyPreserveHost On
    RequestHeader set X-Forwarded-Proto "https"

    ProxyPass /static/ !
    Alias /static/ /srv/myapp/staticfiles/
    <Directory /srv/myapp/staticfiles>
        Require all granted
    </Directory>

    ProxyPass /media/ !
    Alias /media/ /srv/myapp/media/
    <Directory /srv/myapp/media>
        Require all granted
    </Directory>

    ProxyPass / http://127.0.0.1:8001/
    ProxyPassReverse / http://127.0.0.1:8001/

    Header always set X-Content-Type-Options "nosniff"
    Header always set Referrer-Policy "strict-origin-when-cross-origin"
    Header always set X-Frame-Options "DENY"

    ErrorLog ${APACHE_LOG_DIR}/myapp-ssl-error.log
    CustomLog ${APACHE_LOG_DIR}/myapp-ssl-access.log combined
</VirtualHost>
</IfModule>
```

## 24.5 Firewall baseline

```bash
sudo ufw allow OpenSSH comment 'SSH administration'
sudo ufw allow 80/tcp comment 'HTTP redirect and ACME validation'
sudo ufw allow 443/tcp comment 'HTTPS application'
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw enable
sudo ufw status numbered
```

## 24.6 Safe deployment command sequence

```bash
# Inspect first
sudo -u deploy -H bash -lc '
cd /srv/myapp/app
git status --short --branch
git fetch origin
git log --oneline HEAD..origin/main
'

# Pull code
sudo -u deploy -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app
git pull --ff-only origin main
/srv/myapp/venv/bin/pip install -r requirements.txt
'

# Apply app-level changes as the service user
sudo -u myapp -H bash -lc '
set -Eeuo pipefail
cd /srv/myapp/app
set -a
. /etc/myapp/myapp.env
set +a
/srv/myapp/venv/bin/python manage.py check
/srv/myapp/venv/bin/python manage.py migrate --noinput
/srv/myapp/venv/bin/python manage.py collectstatic --noinput
'

# Reload services
sudo systemctl restart myapp-gunicorn
sudo apache2ctl configtest
sudo systemctl reload apache2
```

## 24.7 Safe diagnostic commands

```bash
# Service state
sudo systemctl status myapp-gunicorn apache2 postgresql

# Follow app errors
sudo journalctl -u myapp-gunicorn -f

# Apache logs
sudo tail -F /var/log/apache2/myapp-ssl-access.log /var/log/apache2/myapp-ssl-error.log

# Firewall
sudo ufw status verbose

# Certificate renewal test
sudo certbot renew --dry-run

# Current deployed commit
sudo -u deploy -H bash -lc 'cd /srv/myapp/app && git log -1 --oneline'
```

<div class="chapter-break"></div>

# 25. Common mistakes and the correct mental model

| Mistake | Why it happens | Better model |
|---|---|---|
| Running `runserver` publicly | It worked locally | Development convenience is not a production process manager |
| Running Django as root | Root avoids a permission error temporarily | Fix ownership; run the app as a restricted service user |
| Opening port 5432 | “The app needs the database” | The app on localhost needs it; browsers do not |
| Opening port 8000/8001 | “The app server must be reachable” | Apache reaches Gunicorn locally; public users reach Apache only |
| `chmod -R 777` | File permission debugging is frustrating | Model owner/group/read/write needs deliberately |
| Committing `.env` | Local convenience | Commit `.env.example`; inject real secrets outside Git |
| Editing code on production | Fast emergency fix | Fix locally, test, commit, deploy; document emergency changes |
| Pulling with a dirty server tree | Manual drift accumulated | Keep production code clean; use a controlled config location |
| Always running every command | Ritual | Use migrations/static/dependency steps because a change requires them |
| Disabling CSRF | Form submission gave 403 | Diagnose origin, cookies, HTTPS/proxy header, template token |
| Treating local backup as enough | “There is a dump on the server” | A server loss removes it too; copy off-server and test restore |
| Moving tags | A prior beta was imperfect | Tags are historical snapshots; release a new tag |

# 26. Final operational checklists

## 26.1 Before first public launch

- [ ] Domain DNS points to the intended server.
- [ ] HTTPS certificate covers required hostnames.
- [ ] HTTP redirects to HTTPS.
- [ ] `DEBUG=False`.
- [ ] `ALLOWED_HOSTS` and `CSRF_TRUSTED_ORIGINS` are correct.
- [ ] Secrets are outside Git and protected by filesystem permissions.
- [ ] PostgreSQL and Gunicorn are not publicly exposed.
- [ ] UFW allows only SSH/80/443 inbound.
- [ ] Gunicorn service is enabled and starts after reboot.
- [ ] `collectstatic` succeeded and CSS loads.
- [ ] Database migrations are applied.
- [ ] `manage.py check --deploy` was reviewed.
- [ ] `certbot renew --dry-run` passed.
- [ ] Local and off-server backups exist.
- [ ] A restore drill was performed on a separate database.
- [ ] Health endpoint and uptime monitoring work.
- [ ] Critical user flow was manually tested.

## 26.2 Before each release

- [ ] Tests pass locally/CI.
- [ ] Migration status is understood.
- [ ] Static/dependency changes are understood.
- [ ] Commit is pushed to remote.
- [ ] VPS Git working tree is clean.
- [ ] Incoming changes were reviewed.
- [ ] Database backup is current.
- [ ] Service status and health endpoint are verified after deploy.
- [ ] Release notes/tag are created from the correct commit.

## 26.3 Before making the repository public

- [ ] No secrets in current files or history.
- [ ] Leaked secrets have been rotated.
- [ ] `.gitignore` excludes environment files and keys.
- [ ] `README.md` provides honest setup/run/test instructions.
- [ ] `LICENSE` is selected deliberately.
- [ ] `CONTRIBUTING.md`, `CODE_OF_CONDUCT.md`, and `SECURITY.md` exist.
- [ ] Issue/PR templates exist.
- [ ] CI runs tests.
- [ ] Dependency/security tooling is enabled where appropriate.
- [ ] Production endpoints, IPs, usernames, tokens, and private infrastructure details are not published unnecessarily.

# 27. Glossary

| Term | Meaning |
|---|---|
| ACME | Protocol used by certificate authorities/clients such as Let’s Encrypt and Certbot |
| Apache | Public web server used here for TLS, static files, logging, and reverse proxying |
| ASGI | Python interface for asynchronous server/application communication |
| Certificate | Signed proof that a domain’s server holds an associated private key |
| CDN | Content delivery network, often used for caching/static delivery and edge routing |
| CSRF | Cross-site request forgery protection mechanism for browser form/session security |
| DNS | System mapping domain names to network addresses |
| Gunicorn | Python WSGI application server |
| HSTS | Browser policy telling clients to prefer HTTPS for a domain |
| HTTPS | HTTP secured with TLS |
| Journal | systemd’s log store, queried via `journalctl` |
| Migration | Versioned Django operation changing database schema/data state |
| PostgreSQL role | Database identity/permission set, distinct from Linux users and Django users |
| Reverse proxy | Public server that forwards requests to an internal backend |
| Static files | Rebuildable CSS/JS/images owned by the application source/build |
| Media files | Persistent user uploads that need backup |
| systemd | Linux service manager/supervisor |
| TLS | Cryptographic transport layer used by HTTPS |
| UFW | Ubuntu firewall management command-line tool |
| Virtual host | Apache per-domain configuration block |
| WSGI | Traditional Python web server/application interface |

# 28. Official references

1. **Django deployment overview and supported WSGI/ASGI paths** - Django documentation: https://docs.djangoproject.com/en/6.0/howto/deployment/
2. **Django deployment checklist** - Django documentation: https://docs.djangoproject.com/en/6.0/howto/deployment/checklist/
3. **Apache reverse proxy documentation** - Apache HTTP Server: https://httpd.apache.org/docs/current/mod/mod_proxy.html
4. **Apache virtual host examples** - Apache HTTP Server: https://httpd.apache.org/docs/2.4/vhosts/examples.html
5. **Certbot user guide and renewal behavior** - Certbot documentation: https://eff-certbot.readthedocs.io/en/stable/using.html
6. **Ubuntu UFW/firewall guide** - Ubuntu Server documentation: https://ubuntu.com/server/docs/how-to/security/firewalls/
7. **PostgreSQL `pg_dump` and `pg_restore`** - PostgreSQL documentation: https://www.postgresql.org/docs/current/app-pgdump.html and https://www.postgresql.org/docs/current/app-pgrestore.html
8. **GitHub community health files** - GitHub documentation: https://docs.github.com/en/communities/setting-up-your-project-for-healthy-contributions/about-community-profiles-for-public-repositories
9. **GitHub Actions for Python** - GitHub documentation: https://docs.github.com/actions/guides/building-and-testing-python
10. **GitHub security policy and secret safety** - GitHub documentation: https://docs.github.com/code-security/getting-started/adding-a-security-policy-to-your-repository and https://docs.github.com/en/code-security/concepts/secret-security/push-protection
11. **Semantic Versioning** - https://semver.org/

---

## Final note

A good deployment is not the one with the most tools. It is the one whose responsibilities are understood, whose recovery path is tested, whose secrets and ports are controlled, and whose next operator can safely repeat the process.
