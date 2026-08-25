# Validate Release Notes

## Description

Validates the sectioned release notes of a module. A release is described by a pair of
locale files named after its git tag:

```text
.release-notes/vX.Y.Z.yaml      English
.release-notes/vX.Y.Z.ru.yaml   Russian
```

Sections: `summary` and `highlights` (both required), then `new_features`, `improvements`,
`fixes`, `security`, `breaking`, `upgrade_notes`, `known_issues`, `docs` and
`dependencies`. An empty section is deleted, not left as `[]`. Version and module name
come from the file name and `module.yaml`, not from the document. Optional `date`
(`"YYYY-MM-DD"`), `channels` and `skip_docs`.

The same YAML is what the module's `.werf/release.yaml` merges into the `changelog.yaml`
of the release image, which DKP reads into `ModuleRelease.spec.changelog` and Console
renders — so a section lost to a mistyped key is invisible until a user goes looking for
it. Hence the gate.

**Errors:** a file that does not parse, a top level that is not a mapping, an unknown or
legacy (`Изменения` / `Changes`) key, a missing or empty `summary` or `highlights`, a
section that is not a list of non-empty strings, a dependency without a `name`, a `date`
that is not a quoted `YYYY-MM-DD` string, a non-boolean `skip_docs`, `skip_docs`
disagreeing between the locales, Cyrillic in the English file, no Cyrillic in the Russian
`summary`/`highlights`, and a pair with only one locale present.

**Warnings:** a section left as `[]` or null instead of being deleted, a section present in
one locale only, item counts that differ between the locales, and a `version` or `module`
key that duplicates the file name.

The validator is embedded in the template, so a module release depends on nothing but this
repository and PyYAML.

## Variables

### Optional

- `RELEASE_NOTES_PATH` — release-notes directory, default `.release-notes`.

## Usage

```yaml
include:
  - project: "deckhouse/3p/deckhouse/modules-gitlab-ci"
    ref: v18.0
    file:
      - "/templates/Release_Notes.gitlab-ci.yml"

Validate release notes:
  extends: .release_notes_validate
```

On a tag the pair of that tag must exist and be valid. On a merge request and on the
default branch every pair in the directory is validated, so an edit that breaks an
already-released file is caught too.

A module that has moved to this format also wants:

```yaml
variables:
  # `CHANGELOG/` keeps the history of the releases cut before the move and gains no new
  # files, so the legacy validator must stop demanding a file there on a tag.
  CHANGELOG_REQUIRE_ON_TAG: "false"
```

`Merge_Release.gitlab-ci.yml` looks up `.release-notes/<version>.yaml` first and falls back
to `CHANGELOG/<version>.yml`, so the GitLab Release description works in both formats.
