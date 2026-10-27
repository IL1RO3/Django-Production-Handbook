# Django Production Deployment Guide

> A practical, docs-as-code handbook for moving a bare Django project from a developer laptop to a secure, repeatable production service.

This is the source for a **book built with [MkDocs](https://www.mkdocs.org/)** and the built-in Read the Docs theme. It is ready to publish on **Read the Docs**, and it can also be built and read locally or on any static host.

## What the book is

The guide is deliberately **explanatory**. It teaches what each layer is, why it exists, when to choose it, how the pieces communicate, how to configure them, and how to operate the system after launch. It is written for people who can build a Django project but feel lost the moment it leaves their laptop. Every command is a template with placeholders such as `<PROJECT_PACKAGE>`, `<APP_NAME>`, `<DOMAIN>`, and `<DB_NAME>`, and every step has a "what can go wrong" and a "how to verify" angle.

## What the book covers

- **Getting started** — the production mental model, the request journey, choosing a stack, and the target variables/layout.
- **Django application** — repository hygiene, production settings and secrets, static/media/migrations/health checks, WSGI/ASGI, and email/background tasks/external services.
- **Server setup** — VPS and DNS, SSH users and permissions, PostgreSQL, and systemd/environment files.
- **Deployment stacks** — Gunicorn, Nginx, Apache (+ Gunicorn and + mod_wsgi), Caddy, and ASGI with Uvicorn/Daphne/Hypercorn.
- **Dockerization from zero** — what containers are, writing your first Dockerfile, building and running images, multi-stage builds, Docker Compose, and running Docker in production.
- **Platforms and alternatives** — managed PaaS, Kubernetes, uWSGI, and other valid options.
- **Security and operations** — TLS/HTTPS, firewall and host security, deployment runbooks, observability, backups, testing/CI/staging, and scaling.
- **Open source** — publishing a project, license/governance/security, and releases/maintenance.
- **Reference** — copy-and-adapt config templates, checklists, a troubleshooting map, a glossary, official sources, and line-by-line config walkthroughs.

The book covers the **major architecture families** and gives you a decision process rather than enumerating every provider and framework combination. The reference runbooks target a single Ubuntu VPS with PostgreSQL and a public domain; the concepts transfer to other environments.

## Repository layout

```text
docs/                        Markdown source for every page
docs/index.md                the book's home page
docs/config-examples/        copy-and-adapt templates (nginx, systemd, Dockerfile, etc.)
docs/appendices/             complete-handbook.md — all chapters in one page
mkdocs.yml                   site config, theme, extensions, and navigation
requirements-docs.txt        documentation build dependencies
.readthedocs.yaml            Read the Docs build settings
```

The page source lives under `docs/`, the navigation is defined in `mkdocs.yml`, and Read the Docs reads the build settings from `.readthedocs.yaml`.

## Render it yourself (locally)

You need Python 3.9+ (the docs themselves are version-agnostic).

```bash
# 1. Create and activate a virtual environment.
python -m venv .venv
source .venv/bin/activate        # Windows: .venv\Scripts\activate

# 2. Install the documentation dependencies.
python -m pip install -r requirements-docs.txt

# 3. Start a live preview with auto-reload.
mkdocs serve
```

Open the local URL printed by MkDocs (usually `http://127.0.0.1:8000`). The site rebuilds as you edit.

### Build a static site

To produce a self-contained `site/` directory you can host anywhere:

```bash
mkdocs build
```

Use the strict build to catch broken internal links and missing pages before publishing:

```bash
mkdocs build --strict
```

The generated `site/` directory is git-ignored.

## Publish it

### Read the Docs (recommended)

1. Push this repository to GitHub, GitLab, or Bitbucket.
2. Sign in to [Read the Docs](https://readthedocs.org/) and choose **Add project**.
3. Import the repository and select the branch to publish.
4. Start a build.

Read the Docs finds `.readthedocs.yaml` at the repository root, installs `requirements-docs.txt`, and builds the `mkdocs.yml` project. See [`docs/read-the-docs-setup.md`](docs/read-the-docs-setup.md) for the full walkthrough, including custom domains, versioning, and pull-request previews.

### Any static host

Run `mkdocs build` and upload the contents of `site/` to GitHub Pages, Netlify, Cloudflare Pages, S3, Nginx, or any static file server.

## Configuration files, explained

| File | Purpose |
|---|---|
| `mkdocs.yml` | site name, theme, Markdown extensions, and navigation |
| `requirements-docs.txt` | pins the supported MkDocs release range (`mkdocs>=1.6,<2`) |
| `.readthedocs.yaml` | build image, Python version, dependency file, and MkDocs config for Read the Docs |
| `docs/index.md` | the documentation home page |
| `docs/config-examples/` | templates readers copy and adapt |

When adding or renaming a page, update the `nav` section in `mkdocs.yml` and run `mkdocs build --strict` so missing pages and broken internal links are caught before publication.

## Contributing

Contributions are welcome. The core rules:

- Keep commands safe, explicit, and verified.
- Explain *why* a component or configuration exists, not only what to paste.
- Do not include real secrets, server IPs, or private operational data.
- Prefer official sources for technical claims.
- When you change a deployment chapter, update its config template, the relevant checklist, and the all-in-one appendix.

See [`CONTRIBUTING.md`](CONTRIBUTING.md) for the suggested workflow. The book is licensed under the terms in [`LICENSE`](LICENSE), with the code of conduct in [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md) and the security policy in [`SECURITY.md`](SECURITY.md).

## Safety rule

Every command in the book is a template. Replace placeholders such as `<APP_NAME>`, `<DOMAIN>`, `<DEPLOY_USER>`, and `<PROJECT_PACKAGE>`. Read the explanation and verification step before applying any command to a live system.
