# 26. Testing, CI, staging, and smoke tests

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
