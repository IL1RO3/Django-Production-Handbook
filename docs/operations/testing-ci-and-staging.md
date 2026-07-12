# 29. Testing, CI, staging, and smoke tests

## Testing ladder

| Level | What it proves | Example |
|---|---|---|
| Unit test | isolated logic | slug generation, helper function |
| Model/view integration test | Django components work together | published post URL returns 200 |
| Browser/E2E test | critical user behavior in a real browser | signup → post → admin publish → public open |
| Staging test | production-like infrastructure behavior | proxy/TLS/static/migrations on separate app+DB |
| Production smoke test | deployed release answers basic requests | `/healthz/`, login page, one critical flow |

## Regression tests are operational memory

Every production bug that is inexpensive to encode should become a regression test. It turns a painful incident into protection against repeating it.

Examples for a blog app:

- publishing assigns `pub_date`;
- public post URLs use the intended local calendar date;
- drafts do not build a public detail URL;
- a normal user cannot edit another user’s post;
- CSRF-protected forms accept valid HTTPS-origin submissions.

## GitHub Actions example

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
      - run: python manage.py check
      - run: python manage.py test
```

Real projects may need a PostgreSQL service container and CI-only environment variables. Keep credentials test-only and do not copy production secrets into CI.

## Staging

A staging environment should be isolated:

```text
staging.example.com
separate app checkout/service
separate environment file
separate database
separate media/static location
safe test email recipient/backend
```

Do not point a feature branch at production data to “test for real.” Test migrations and POST actions against staging data. Production-like does not mean production-coupled.

## Browser tests

Playwright is a strong choice for real browser flows. Begin with one critical journey, not an enormous flaky suite:

```text
sign up → log in → create record → privileged publish/approve → public URL opens → dashboard works
```

## Production smoke tests

After each deploy, run a short, repeatable smoke check. It should be fast enough that you actually do it.

## Walk through the GitHub Actions workflow

```yaml
name: Django CI
```

This is the human-readable workflow name shown in GitHub.

```yaml
on:
  push:
  pull_request:
```

Run the workflow when code is pushed and when a pull request is opened or updated.

```yaml
jobs:
  test:
    runs-on: ubuntu-latest
```

A workflow contains jobs. This job is named `test` and runs on a fresh Ubuntu runner hosted by GitHub.

```yaml
- uses: actions/checkout@v4
```

Download your repository into the runner.

```yaml
- uses: actions/setup-python@v5
  with:
    python-version: "3.12"
```

Install and select Python 3.12 for the job.

```yaml
- run: python -m pip install --upgrade pip
- run: pip install -r requirements.txt
```

Upgrade pip and install project dependencies.

```yaml
- run: python manage.py check
- run: python manage.py test
```

Run Django's configuration checks and test suite. If either command exits non-zero, the CI job fails.

## Adding PostgreSQL to CI

A real app often needs PostgreSQL in CI. That usually means adding a service container and test-only environment variables. Keep the CI database disposable. Never point CI at production PostgreSQL.

## CI is not deployment by itself

CI answers "does this revision pass automated checks?" Deployment answers "is this revision safely running on an environment?" A professional pipeline may combine them, but they are separate responsibilities.
