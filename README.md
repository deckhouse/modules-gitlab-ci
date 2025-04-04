# gitlab-ci

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

## Multi-repository templates

In `templates/multi-repo` the CI workflow differs from `basic` CI (which in `templates`) in the following key aspects:

- In `multi-repo` workflow we can push to `dev` and `prod` registries separately with their own rules (see `jobs/multi-repo` and/or `examples/multi-repo-module.gitlab-ci.yml` for example jobs).
- All werf's caches and other artifacts (from `build` stage) are stored in Gitlab's module's registry by default. And **only final images** are pushed to the dev/prod registries. So, even in dev-registry there **should be no** "build-time garbage" and/or some "extra" images/layers for each module.

### Detailed differences between `multi-repo` and `basic` workflows

- [General] There is additional stage `lint` before `build` and `cleanup` stage after `deploy`.
- [General] All `only` sections (like `only: [tags, branches]`) replaced with corresponding `rules` section.
- [General] Added `Scheduled cleanup` job to cleanup Gitlab's registry by pipeline schedule
- [General] Added `Auto cleanup` job to cleanup Gitlab's registry BEFORE `build` stage. Can be disabled via `AUTO_CLEANUP="false"` variable.
- [General] Added `.default_rules` hidden job (see `templates/multi-repo/Setup.gitlab-ci.yml`) for easy modification of this whole workflow.
- [General] Added `.deploy-prod-rules` hidden job (see `templates/multi-repo/Deploy.gitlab-ci.yml`) for easy modification of `deploy to production` workflow.
- [General] Added `jobs/multi-repo` jobs files which user can include and use in their own workflow.
- [Refactor] Default `before_script` section (see `templates/Setup.gitlab-ci.yml`) moved to `.setup/before_script` job.
- [Refactor] `dmt lint` job moved to `lint` stage in dedicated `templates/multi-repo/Lint.gitlab-ci.yml` file.
- [Refactor] All werf's caches and other artifacts (from `build` stage) are stored in Gitlab's registry (`${CI_REGISTRY_IMAGE}/${MODULES_MODULE_NAME}`) by default.
- [Refactor] Images publishing (via `crane copy`) and module's self-registration processes moved to dedicated hidden job `.publish` (see `templates/multi-repo/Deploy.gitlab-ci.yml`).

## Variables

`$MODULES_REGISTRY` - base URL for the registry, e.g. `registry.example.com`
`$MODULES_REGISTRY_PATH` - path to modules repository in registry, e.g. `deckhouse/modules`
`$MODULES_MODULE_NAME` (Optional) - module name, by default it is equal to the project name
`$RELEASE_CHANNEL` - lowercase release channel name, e.g., `alpha`, `stable`, `early-access`
