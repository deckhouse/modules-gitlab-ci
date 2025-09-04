# gitlab-ci

Helper functions for building and delivering Deckhouse modules using Gitlab CI with support for image and binary signing.

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
WERF_SIGN_MANIFEST: "true"                              # Enable image manifest signing
WERF_BSIGN_ELF_FILES: "1"                              # Enable ELF binary signing
WERF_ANNOTATE_LAYERS_WITH_DM_VERITY_ROOT_HASH: "true"  # Enable dm-verity annotations
```
