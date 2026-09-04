<p align="center">
  <img alt="Deckhouse Kubernetes Platform" src="docs/images/logos/DH_sign_dark_mode.svg#gh-dark-mode-only" alt="Deckhouse Kubernetes Platform" />
  <img alt="Deckhouse Kubernetes Platform" src="docs/images/logos/DH_sign_light_mode.svg#gh-light-mode-only" alt="Deckhouse Kubernetes Platform" />
</p>

# Deckhouse Modules GitLab-CI

Helper functions for building and delivering Deckhouse modules using Gitlab CI.

## Main Idea

This repository contains code for Gitlab CI job templates that can be reused. The templates are located in the [`templates`](templates/) directory.

To connect a template, you need to add the following code to your `.gitlab-ci.yml`:

```yaml
include:
- remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/main/templates/Setup.gitlab-ci.yml'
- remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/main/templates/Build.gitlab-ci.yml'

default:
  tags:
  - my-runner

Build:
  extends: .build
```

> Instead of `/main/`, you can specify a specific commit to ensure changes do not affect your CI. 

The [`examples`](examples/) folder contains examples of `.gitlab-ci.yml` that can be assembled from the templates.

## Merge MR and Create Release

Template **Merge_Release.gitlab-ci.yml** implements the same flow as [modules-actions merge-and-release](https://github.com/deckhouse/modules-actions/tree/main/merge-and-release) (PR [#57](https://github.com/deckhouse/modules-actions/pull/57)):

1. **Trigger:** Add label `release` or `ready-for-release` to a Merge Request and run the pipeline.
2. **Version:** Extracted from MR title (e.g. `v0.3.17` or `0.3.17`).
3. **Merge:** MR is merged via GitLab API (merge commit, delete source branch).
4. **Tag:** A tag is created on the base branch and pushed (triggers tag pipelines, e.g. Build/Deploy).
5. **Release:** GitLab Release is created with description from `.release-notes/<version>.yaml`, falling back to `CHANGELOG/<version>.yml`.

**Required:** CI/CD variable `RELEASE_TOKEN` (masked) — GitLab token with `api` and `write_repository` (Personal or Project Access Token).

**Optional variables:** `MERGE_RELEASE_NOTES_PATH` (default: `.release-notes`), `MERGE_RELEASE_CHANGELOG_PATH` (default: `CHANGELOG`), `MERGE_RELEASE_BASE_BRANCH` (default: `main`).

Example: see [`examples/merge-and-release.gitlab-ci.yml`](examples/merge-and-release.gitlab-ci.yml).

## Publish on a Release Tag

**Build.gitlab-ci.yml** provides the `.prod_build_rules` anchor: a module that references it publishes automatically once a release tag exists, instead of asking for one click per edition.

1. **`vX.Y.Z`** (exactly three numeric components — the shape `Merge_Release` creates): the prod build starts on its own.
2. **Any other tag** (release candidate, hand-made, experimental): stays `when: manual`, so an ad-hoc tag never writes to the prod registry by itself.
3. **Deploy jobs are untouched:** moving a release channel remains a separate manual decision.

Usage in a project — the `needs` is what makes the release gates binding:

```yaml
build_prod:
  stage: build
  extends: [.build, .prod]
  rules: !reference [.prod_build_rules, rules]
  needs: ["Validate release notes"]
  parallel:
    matrix: *prod_build_matrix
```

Only for a module on the sectioned release-notes format: the gate job referenced by `needs` has to exist in the tag pipeline.

## Validate Release Notes

Template **Release_Notes.gitlab-ci.yml** validates the sectioned release notes of a module — a pair of locale files `.release-notes/<tag>.yaml` and `<tag>.ru.yaml` with `summary`, `highlights` and the optional `new_features`, `improvements`, `fixes`, `security`, `breaking`, `upgrade_notes`, `known_issues`, `docs` and `dependencies` sections.

1. **Trigger:** tag pipelines, merge requests, and the default branch.
2. **On a tag:** the pair of that tag must exist and pass validation.
3. **Otherwise:** every pair in the directory is validated, so an edit that breaks an already-released file is caught too.

The validator is embedded in the template: a module release depends on nothing but this repository and PyYAML.

**Optional variables:** `RELEASE_NOTES_PATH` (default: `.release-notes`).

Details: see [`docs/Release_Notes.gitlab-ci.md`](docs/Release_Notes.gitlab-ci.md).

## Create Release MR

The same template carries **`.release_notes_create_mr`**, which opens the merge request of a
release — the sectioned format has no translation step, so nothing else did.

1. **Trigger:** a push to a non-default branch (never a tag).
2. **Version:** from the release-notes files the commit touched, falling back to the version in
   the branch name (`v0-1-24-changelog`).
3. **Validation:** that version's pair must be valid, or the job fails and creates nothing.
4. **MR:** titled `Release vX.Y.Z` (where `Merge and Release` reads the version from), described
   with both locale files, idempotent — an already open MR for the branch is left alone.

It never merges, tags or labels: `release` on the MR plus a pipeline rerun stays a human
decision.

**Required:** CI/CD variable `RELEASE_TOKEN` (`api` scope) — `CI_JOB_TOKEN` cannot create a merge
request.

**Optional variables:** `RELEASE_NOTES_BASE_BRANCH` (default: `main`).

## Translate Changelog and Create MR

Template **Translate_Changelog.gitlab-ci.yml** implements the same flow as [modules-actions translate-changelog](https://github.com/deckhouse/modules-actions/tree/main/translate-changelog) (PR [#57](https://github.com/deckhouse/modules-actions/pull/57)):

1. **Trigger:** Pipeline runs on **push** to any branch except the default branch.
2. **Check:** If the last commit changed any `CHANGELOG/*.ru.yml` file.
3. **Translate:** Finds the latest Russian changelog, translates it to English (`.yml`), commits and pushes.
4. **Create MR:** Creates a Merge Request to the base branch with title = version (e.g. `v0.3.17`).

**Optional variables:** `TRANSLATE_CHANGELOG_PATH` (default: `CHANGELOG`), `TRANSLATE_BASE_BRANCH` (default: `main`). Optional `RELEASE_TOKEN` for push/MR; otherwise `CI_JOB_TOKEN` is used.

Example: see [`examples/translate-changelog.gitlab-ci.yml`](examples/translate-changelog.gitlab-ci.yml).
