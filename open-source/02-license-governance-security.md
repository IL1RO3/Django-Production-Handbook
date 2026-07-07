# 32. License, governance, contribution, and security policy

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

## Issue and pull request templates

Templates reduce incomplete reports. A useful bug report asks for:

- project version or commit;
- Django/Python/database versions;
- deployment stack if relevant;
- expected behavior;
- actual behavior;
- minimal reproduction;
- logs or traceback with secrets removed.

A useful pull request template asks for purpose, linked issue, test evidence, documentation updates, migration notes, and breaking-change impact. Keep templates short enough that contributors will actually complete them.

## Roadmap and support policy

A roadmap tells users what direction the project is taking. A support policy tells them what is maintained today. For documentation projects, state which Django versions, operating systems, and server stacks the guide actively tests or targets.

## Documentation contribution guide

Documentation has code-like quality rules. Ask contributors to keep commands copyable, explain placeholders, avoid real secrets/IPs, update both templates and explanatory chapters when needed, and cite official documentation for claims that change over time.
