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
