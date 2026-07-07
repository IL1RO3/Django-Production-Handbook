# 33. Releases, SemVer, changelogs, and support

## Git commits, tags, and releases

- A **commit** is a source snapshot in history.
- A **branch** is a movable pointer to a line of work.
- A **tag** is a named pointer to a specific commit, useful for immutable release snapshots.
- A **release** is a human-facing publication around a tag: notes, downloads, known limitations, migration instructions.

Do not retarget a release tag after users may have consumed it unless correcting a serious mistake and communicating clearly. Create the next version instead.

## Semantic Versioning

`MAJOR.MINOR.PATCH` communicates compatibility intent:

```text
1.4.2
│ │ └─ compatible bug fix
│ └─── backward-compatible feature
└───── breaking change
```

Pre-release identifiers communicate instability/testing:

```text
0.2.0-beta.1
0.2.0-beta.2
0.2.0-rc.1
0.2.0
```

Use a new beta number for meaningful fixes after the previous beta. Do not call a release final merely because it has a tag; call it final when its support/compatibility promise is real.

## Changelog style

A useful release note includes:

```md
## Fixed
- Corrected timezone-aware public post URL generation.

## Added
- Added regression test for posts created near local midnight.

## Changed
- Documented production backup timer.

## Upgrade notes
- Run migrations: ...
- Run collectstatic: ...
```

## Support boundaries

State what is supported: Python/Django versions, database version, Linux target, deployment patterns, browser support, and security support window. Clear boundaries prevent users from assuming an untested configuration is guaranteed.

## Release checklist

Before publishing a release:

- run link and Markdown checks if available;
- verify examples against supported Django/Python versions where practical;
- confirm templates match the chapters;
- update changelog and upgrade notes;
- tag the release;
- publish human-readable release notes;
- announce breaking changes clearly.

For a GitBook, also verify that navigation renders correctly after Git sync and that renamed pages do not leave broken links.

## Maintenance rhythm

Production guidance ages. Review the book on a schedule for Django LTS changes, Ubuntu LTS changes, PostgreSQL support windows, TLS/certificate client changes, package names, and deployment-tool behavior. Mark unverified patterns as unverified rather than letting readers assume they are current.

## Security maintenance

Security fixes should have a private intake path, a clear maintainer owner, a release note that avoids unnecessary exploit detail, and a supported-version statement. If a vulnerable command or configuration appears in the book, fix the chapter, template, reference checklist, and any all-in-one appendix that repeats it.
