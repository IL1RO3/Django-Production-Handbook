# 30. Releases, SemVer, changelogs, and support

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
