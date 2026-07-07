# Import this repository into GitBook

GitBook supports docs-as-code workflows through Git synchronization. This directory is intentionally plain Markdown so it remains useful in GitHub, GitLab, an editor, or another static documentation system even before GitBook is connected.

## 1. Create a documentation repository

Create a new GitHub or GitLab repository, for example:

```text
django-production-guide
```

Copy this directory into it, then commit it:

```bash
git init
git add .
git commit -m "Add Django deployment guide"
git branch -M main
git remote add origin <YOUR_REPOSITORY_URL>
git push -u origin main
```

## 2. Connect GitBook

In GitBook, create a new Space or import existing content, select Git Sync, authenticate your Git provider, and select this repository and branch. GitBook can import Markdown content from the repository and keep it synchronized with Git changes.

Use the repository root as the documentation root. `README.md` is the landing page. `SUMMARY.md` contains a portable navigation outline; if GitBook presents an editor-side navigation tree, reproduce that outline there.

## 3. Editing workflow

Use a branch and pull request for material changes:

```text
main               → published documentation
feature/new-stack  → draft change
pull request       → review
merge              → GitBook sync publishes the change
```

## 4. Keep the book accurate

Deployment documentation gets stale quickly. For each significant change, update:

- the relevant config template,
- its explanatory chapter,
- the release/upgrade runbook,
- the security and backup notes when appropriate,
- the book version or changelog.

Do not store live secrets, server IPs, certificate private keys, database passwords, or tokens in this documentation repository.
