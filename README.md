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
- [General] Added ability to specify which module's `EDITION` (`CE`, `EE`, etc) should be pushed to PRODUCTION registry.
- [Refactor] Default `before_script` section (see `templates/Setup.gitlab-ci.yml`) moved to `.setup/before_script` job.
- [Refactor] `dmt lint` job moved to `lint` stage in dedicated `templates/multi-repo/Lint.gitlab-ci.yml` file.
- [Refactor] All werf's caches and other artifacts (from `build` stage) are stored in Gitlab's registry (`${CI_REGISTRY_IMAGE}/${MODULES_MODULE_NAME}`) by default.
- [Refactor] Images publishing (via `crane copy`) and module's self-registration processes moved to dedicated hidden job `.publish` (see `templates/multi-repo/Deploy.gitlab-ci.yml`).

## Image and Binary Signing

The templates now support signing of container images and ELF binaries within those images using werf's built-in signing capabilities.

### Features

- **Image signing**: Container image manifests are signed using certificates
- **Binary signing**: ELF binaries within images are signed using GPG keys

### Required Variables

To enable signing, configure the following variables in your GitLab CI/CD project settings:

#### Secret Variables (GitLab CI/CD Variables)

- `WERF_SIGN_CERT` - Certificate for image signing (base64 encoded)
- `WERF_SIGN_INTERMEDIATES` - Intermediate certificates (base64 encoded)
- `WERF_SIGN_KEY` - Private key for signing (base64 encoded)
- `VAULT_ROLE_ID` - Vault role ID for accessing GPG keys
- `VAULT_SECRET_ID` - Vault secret ID for accessing GPG keys
- `VAULT_ADDR` - Vault URL
- `WERF_ELF_PGP_PRIVATE_KEY_FINGERPRINT` - GPG key fingerprint for binary signing
- `WERF_ELF_PGP_PRIVATE_KEY_PASSPHRASE` - GPG key passphrase

### Configuration

The signing is enabled by default when using the templates. The following environment variables are automatically configured:

```yaml
WERF_SIGN_MANIFEST: "true"                             # Enable image manifest signing
WERF_BSIGN_ELF_FILES: "1"                              # Enable ELF binary signing
WERF_ANNOTATE_LAYERS_WITH_DM_VERITY_ROOT_HASH: "true"  # Enable dm-verity annotations
```

## Variables

`$MODULES_REGISTRY` - base URL for the registry, e.g. `registry.example.com`
`$MODULES_REGISTRY_PATH` - path to modules repository in registry, e.g. `deckhouse/modules`
`$MODULES_MODULE_NAME` (Optional) - module name, by default it is equal to the project name
`$RELEASE_CHANNEL` - lowercase release channel name, e.g., `alpha`, `stable`, `early-access`
