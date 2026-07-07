# 29. License, governance, contribution, and security policy

## Choose a license intentionally

A repository without a license is not a clear invitation for reuse. Common broad choices:

| License | Practical meaning |
|---|---|
| MIT | short permissive license; reuse with notice/disclaimer |
| Apache-2.0 | permissive with explicit patent terms |
| GPL-3.0 | copyleft; derivative distribution generally remains GPL-compatible |
| AGPL-3.0 | copyleft that also addresses network-service distribution |

This is not legal advice. Choose based on your goals, dependencies, organization, and jurisdiction. Do not copy a license you do not intend to honor.

## CONTRIBUTING.md

Tell contributors:

- supported setup path,
- branch/PR workflow,
- test commands,
- coding/style expectations,
- how to propose features and report bugs,
- how to handle migrations/docs/changelog changes.

## CODE_OF_CONDUCT.md

For community-facing projects, a code of conduct gives a clear behavior standard and a reporting route. Use a recognized template appropriate to your community, then name a real contact path.

## SECURITY.md

A security policy should contain:

- supported versions,
- private reporting contact/path,
- what information helps reproduce a vulnerability,
- what response timeline is realistic,
- a statement not to post exploitable details as public issues before coordination.

## Governance is operational clarity

Even a one-person project benefits from defined rules: who merges, how releases are cut, what branches are protected, what testing is required, and how breaking changes are communicated.
