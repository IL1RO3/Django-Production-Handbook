# 31. Publishing an open-source project

Public code is not automatically an open-source project. A usable public project needs a license, accurate setup instructions, contribution expectations, and a security path.

## Before making a repository public

- remove secrets from current files and Git history where necessary;
- confirm `.env`, private keys, database dumps, uploads, and local config are ignored;
- replace real values with `.env.example` placeholders;
- include a license;
- write a README that explains what the project does and how to run it;
- add a security reporting policy;
- document supported Python/Django/database versions;
- ensure screenshots/test content do not leak private data;
- run secret scanning or at minimum search tracked history/files.

## Secret checks

```bash
git grep -nEi 'secret|password|token|api[_-]?key|private[_-]?key' || true
git ls-files | grep -E '(^|/)(\.env|.*\.pem|.*\.key)$' || true
```

These are not complete secret scanners, but they create a useful review habit.

## README outline

```md
# Project Name

One-paragraph purpose statement.

## Features
## Screenshots / demo
## Quick start
## Configuration
## Local development
## Testing
## Production deployment
## Contributing
## Security
## License
```

## `.env.example`

A new contributor needs to know variable names without receiving real values:

```dotenv
DJANGO_SECRET_KEY=replace-me-for-local-development
DJANGO_DEBUG=True
DJANGO_ALLOWED_HOSTS=localhost,127.0.0.1
POSTGRES_DB=myproject
POSTGRES_USER=myproject
POSTGRES_PASSWORD=replace-me
POSTGRES_HOST=127.0.0.1
POSTGRES_PORT=5432
```

## Documentation-as-code

Keep technical documentation in Markdown next to the code. This makes setup instructions reviewable in pull requests and versioned alongside the code that they describe. GitBook Git Sync can publish that Markdown as a documentation site.
