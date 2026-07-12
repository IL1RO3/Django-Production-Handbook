# Publish this book on Read the Docs

This repository uses MkDocs with the built-in Read the Docs theme. Its navigation lives in `mkdocs.yml`, its pages live under `docs/`, and Read the Docs reads the build settings from `.readthedocs.yaml`.

## Preview the book locally

Create a virtual environment, install the documentation dependencies, and start the preview server:

```bash
python -m venv .venv
source .venv/bin/activate
python -m pip install -r requirements-docs.txt
mkdocs serve
```

Open the local URL printed by MkDocs. Before publishing a change, run the same strict build used for validation:

```bash
mkdocs build --strict
```

## Import the project

1. Push this repository to GitHub, GitLab, or Bitbucket.
2. Sign in to Read the Docs and choose **Add project**.
3. Import the repository and select the branch that should be published.
4. Start a build.

Read the Docs finds `.readthedocs.yaml` at the repository root, installs `requirements-docs.txt`, and builds the `mkdocs.yml` project.

## Configuration files

- `.readthedocs.yaml` selects the build image, Python version, dependency file, and MkDocs configuration.
- `mkdocs.yml` defines the site metadata, theme, Markdown extensions, and navigation.
- `requirements-docs.txt` pins the supported MkDocs release range.
- `docs/index.md` is the documentation home page.
- `docs/config-examples/` contains files readers can copy and adapt.

When adding or renaming a page, update `nav` in `mkdocs.yml` and run a strict build so missing pages and broken internal links are caught before publication.

## Publishing workflow

Use branches and pull requests for material changes:

```text
main               → published documentation
feature/new-stack  → draft documentation
pull request       → preview, review, and validation
merge              → Read the Docs rebuilds the site
```

You can configure a custom domain, versioning, pull-request builds, and build notifications in the Read the Docs project settings.

## Keep the book safe and accurate

For each significant deployment change, update the relevant configuration example, its explanatory chapter, and any affected security, backup, or release runbook. Never commit live secrets, private keys, database passwords, server addresses, or access tokens.
