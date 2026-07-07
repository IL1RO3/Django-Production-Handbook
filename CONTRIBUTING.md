# Contributing

Thank you for improving this guide.

## Contribution rules

- Keep commands safe, explicit, and verified.
- Explain *why* a component/configuration exists, not only what to paste.
- Mark provider-specific instructions clearly.
- Do not include real secrets, server IPs, or private operational data.
- Prefer official sources for technical claims.
- Update the matching checklist/reference template when changing a deployment chapter.
- Test Markdown links and code fences before opening a pull request.

## Suggested workflow

```bash
git checkout -b docs/improve-nginx-chapter
# edit
# review links and examples
git add .
git commit -m "Clarify Nginx upstream verification"
git push -u origin docs/improve-nginx-chapter
```

Open a pull request explaining the audience, scenario, and any version assumptions.
