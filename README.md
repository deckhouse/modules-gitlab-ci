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
3. **Merge:** MR is merged via GitLab API (squash, delete source branch).
4. **Tag:** A tag is created on the base branch and pushed (triggers tag pipelines, e.g. Build/Deploy).
5. **Release:** GitLab Release is created with description from `CHANGELOG/<version>.yml`.

**Required:** CI/CD variable `RELEASE_TOKEN` (masked) — GitLab token with `api` and `write_repository` (Personal or Project Access Token).

**Optional variables:** `MERGE_RELEASE_CHANGELOG_PATH` (default: `CHANGELOG`), `MERGE_RELEASE_BASE_BRANCH` (default: `main`).

Example: see [`examples/merge-and-release.gitlab-ci.yml`](examples/merge-and-release.gitlab-ci.yml).

## Translate Changelog and Create MR

Template **Translate_Changelog.gitlab-ci.yml** implements the same flow as [modules-actions translate-changelog](https://github.com/deckhouse/modules-actions/tree/main/translate-changelog) (PR [#57](https://github.com/deckhouse/modules-actions/pull/57)):

1. **Trigger:** Pipeline runs on **push** to any branch except the default branch.
2. **Check:** If the last commit changed any `CHANGELOG/*.ru.yml` file.
3. **Translate:** Finds the latest Russian changelog, translates it to English (`.yml`), commits and pushes.
4. **Create MR:** Creates a Merge Request to the base branch with title = version (e.g. `v0.3.17`).

**Optional variables:** `TRANSLATE_CHANGELOG_PATH` (default: `CHANGELOG`), `TRANSLATE_BASE_BRANCH` (default: `main`). Optional `RELEASE_TOKEN` for push/MR; otherwise `CI_JOB_TOKEN` is used.

Example: see [`examples/translate-changelog.gitlab-ci.yml`](examples/translate-changelog.gitlab-ci.yml).
