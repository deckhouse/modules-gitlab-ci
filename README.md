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

## Variables

`$MODULES_MODULE_SOURCE` - base URL for the registry, e.g., `registry.example.com/deckhouse/modules`
`$MODULES_MODULE_NAME` (Optional) - module name, by default it is equal to the project name
`$WERF_REPO` - registry path, default `${MODULES_MODULE_SOURCE}/${MODULES_MODULE_NAME}`
