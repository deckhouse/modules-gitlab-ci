# CVE_Scan — GitLab CI integration

The template runs **Trivy** scans of the module images (and related images) and uploads reports to **DefectDojo**. The `cve_scan.sh` script chooses dev vs release tags and builds registry paths.

Non-standard module paths in prod/dev registries are set with **`MODULE_PROD_REGISTRY_CUSTOM_PATH`** and **`MODULE_DEV_REGISTRY_CUSTOM_PATH`** (template defaults are Deckhouse paths for external modules).

## Typical workflows

- **Scheduled** — periodically scan the default branch and several latest releases (e.g. 2–3 times per week).
- **Merge request** — scan images for the branch/MR tag for new or unresolved issues.
- **Manual** — set a tag or branch for `SOURCE_TAG` (via a pipeline variable or `rules`); optionally scan several latest releases (`SCAN_SEVERAL_LATEST_RELEASES: "True"`, `LATEST_RELEASES_AMOUNT`).

## Including the template

In the root `.gitlab-ci.yml`:

```yaml
include:
  - remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/<branch>/templates/CVE_Scan.gitlab-ci.yml'

stages:
  - build
  - cve_scan
  # …
```

A fuller job skeleton: **`examples/simple-module.gitlab-ci.yml`** (adjust `include`, job names in `needs`, and runner `tags` if required).

### Important: do not override `before_script`

In `.cve_scan`, **`before_script`** installs/uses **d8**, obtains a **Seguro/BOB (Vault)** token, resolves variables prefixed with **`vault:`**, configures SSH, clones the scripts repository, and copies `*.sh` / `*.py`.

If you define **`before_script`** on your job, it **replaces** the template’s entirely — secrets from BOB will not be resolved, and logs will still show strings like `vault:projects/...`.

Do **not** follow the old note “Override before_script as not needed” with the **current** template.

## Seguro (BOB) and secrets

- Sensitive values in the template use **`vault:path#key`** (secret `Trivy_CVE_Scan_CI_Secrets` and others — see `templates/CVE_Scan.gitlab-ci.yml`).
- The GitLab project or group needs **`VAULT_ROLE`**: the Fox JWT role name configured in Seguro (`bound_audiences: gitlab-access-aud`). Policies and roles live in the **`seguro-policy`** repo (README, GitLab section).
- For BOB reads to work, runners need **`d8`/stronghold**, access to **Seguro**, and the runner tags your org uses for these jobs.

**Override without BOB:** in the module job you can set the same variable to a **plain** value (e.g. `PROD_REGISTRY: ${PROD_READ_REGISTRY}` from GitLab group variables) — it overrides the template’s `vault:…` string.

Full list of environment variables for `cve_scan.sh`: the **`cve-scan`** repository (`README.md`).

## Pipeline variables (global, optional)

Declare in `variables:` with `description` so manual runs can set values from the UI:

| Variable | Purpose |
|----------|---------|
| `CVE_RELEASE_TO_SCAN` | Tag/branch for manual runs; often mapped to `SOURCE_TAG` in a `web` rule (legacy name in older docs) |
| `SCAN_SEVERAL_LATEST_RELEASES` | **`"True"`** / **`"False"`** (must match `cve_scan.sh`; legacy name `CVE_SCAN_SEVERAL_LASTEST_RELEASES`) |
| `LATEST_RELEASES_AMOUNT` | How many latest releases to scan when several-releases mode is on; default **3** |
| `TRIVY_REPORTS_LOG_OUTPUT` | `0` — no log, `1` — CVE only, `2` — CVE and licenses (see template) |
| `MODULE_PROD_REGISTRY_CUSTOM_PATH` | Module path in prod registry (default: `deckhouse/fe/modules`) |
| `MODULE_DEV_REGISTRY_CUSTOM_PATH` | Module path in dev registry (default: `sys/deckhouse-oss/modules`) |
| `DIGEST_FROM_WERF` | Werf digest filename (external module scenario) |

## Module job variables (you must set)

| Variable | Description |
|----------|-------------|
| **`VAULT_ROLE`** | Fox role in Seguro for this job/project |
| **`CASE`** | Script scenario; for Deckhouse external modules use **`"External Modules"`** |
| **`EXTERNAL_MODULE_NAME`** | Module name in registry paths |
| **`RELEASE_IN_DEV`** | **`"True"`** / **`"False"`** as in `cve_scan.sh` (case matters) |
| **`SOURCE_TAG`** | Tag or branch to scan (`main`, `mr123`, branch slug, etc.) — usually via **`rules` → `variables`** |

Registries and tokens (**`PROD_*`**, **`DEV_*`**, **`DD_*`**, **`TRIVY_PROD_REGISTRY`**, keys for cloning `cve-scan`, …) default from **BOB** via paths in the template; override them in **`cve_scan.variables`** with normal references to project/group CI/CD variables if needed.

## Example job

```yaml
cve_scan:
  stage: cve_scan
  extends:
    - .cve_scan
  variables:
    CASE: "External Modules"
    EXTERNAL_MODULE_NAME: my-module
    RELEASE_IN_DEV: "False"
    VAULT_ROLE: "your-fox-role-name"
  rules:
    - if: $CI_PIPELINE_SOURCE == "merge_request_event"
      needs: ["Build"]
      variables:
        SOURCE_TAG: mr${CI_MERGE_REQUEST_IID}
    - if: $CI_COMMIT_BRANCH == $CI_DEFAULT_BRANCH
      needs: ["Build"]
      variables:
        SOURCE_TAG: ${CI_DEFAULT_BRANCH}
    - if: $CI_COMMIT_TAG
      variables:
        SOURCE_TAG: ${CI_COMMIT_TAG}
      when: manual
    - if: $CI_PIPELINE_SOURCE == "schedule"
      variables:
        SCAN_SEVERAL_LATEST_RELEASES: "True"
        LATEST_RELEASES_AMOUNT: "3"
        SOURCE_TAG: ${CI_DEFAULT_BRANCH}
    - if: $CI_PIPELINE_SOURCE == "web"
      variables:
        SOURCE_TAG: ${CVE_RELEASE_TO_SCAN}
```

You can move some variables to the global **`variables:`** block if they are shared across jobs.

## Legacy names (migration from older docs)

Older docs used **`TAG`** and **`MODULE_NAME`**. The current `cve_scan.sh` and template use **`SOURCE_TAG`**, **`EXTERNAL_MODULE_NAME`**, and **`CASE`**. Old examples that only overrode `before_script` and did not use BOB **do not match** the current template.

## References

- Template: `templates/CVE_Scan.gitlab-ci.yml`
- Example: `examples/simple-module.gitlab-ci.yml`
- Documentation: [ssdlc wiki](https://wiki.flant.ru/doc/skanirovanie-cvelicense-1HUtHAMSD8)
