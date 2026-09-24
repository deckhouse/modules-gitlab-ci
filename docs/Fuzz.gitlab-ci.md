# Fuzz build and corpus replay

`Build_Fuzz.gitlab-ci.yml` and `Replay_Fuzz.gitlab-ci.yml` extract the flow from
`operator-argo`, branch `internal-migrate-to-delivery-kit`, commit `f3cd709`.
Include `Build_Fuzz` in a project and define two jobs:

```yaml
include:
  - project: deckhouse/3p/deckhouse/modules-gitlab-ci
    ref: &fuzz_templates_ref fuzz-build-replay-templates
    file: /templates/Build_Fuzz.gitlab-ci.yml

variables:
  FUZZ_REPLAY_TEMPLATE_REF: *fuzz_templates_ref

build_fuzz:
  extends: [.fuzz_build, .dev-variables]

replay_fuzz:
  extends: [.fuzz_replay, .dev-variables]
```

Add `fuzz` after `build` in the project's `stages`. Keep the existing setup and
`.dev-variables` registry mixin, applying the mixin to **both** jobs: the trigger
forwards those variables to the child pipeline. Keep the name `build_fuzz`,
which the trigger and child jobs use to fetch artifacts.

The full [example](../examples/fuzz-build-replay.gitlab-ci.yml) includes setup and
registry configuration. The branch must be available in the GitLab template
project before it can be included. Use the same branch, tag or commit SHA for
the include and `FUZZ_REPLAY_TEMPLATE_REF`; the YAML anchor keeps them in sync.

## Execution

1. `build_fuzz` discovers images ending in `-fuzz`, builds and pushes them with
   werf, filters the build report to those images, and adds source metadata.
   It saves `images_fuzz_tags_werf.json` and `fuzz-replay-pipeline.yml` as artifacts
   for seven days. An empty image list or build report fails the build.
2. `replay_fuzz` starts the generated child pipeline and waits for its result.
   The generated configuration includes `Replay_Fuzz.gitlab-ci.yml` from this
   repository at the selected ref; projects do not need a local replay template.
   Each image gets a separate replay job and downloads the parent build report.
3. Replay downloads minimized, recovery and Go cache corpus seeds from
   `s3://anomaloys-materials/<repository>/<branch>/<component>/`. It discovers
   targets with `task fuzz:list`, copies the seeds to `testdata/fuzz`, and runs
   each target with `go test -run`, without starting a fuzzing campaign.
4. Failed targets retain JSON events, logs, corpus files and reproduction
   commands under `fuzz-replay/`. The summary and diagnostics are collected from
   the stopped container, uploaded even on failure, and retained for seven days.
5. On the default branch, `publish_fuzz_report` uploads the build report to
   `s3://anomaloys-materials/build-reports/<repository>/<branch-slug>/` only after
   all replay jobs succeed. A failed replay fails the parent trigger as well.

The templates use GitLab's [dynamic child pipelines and parent artifact
dependencies](https://docs.gitlab.com/ci/pipelines/downstream_pipelines/).
The generated include contains literal project/ref/file values because a
dynamic child pipeline cannot expand variables in its `include` section.

## Rules and variables

Both parent jobs inherit `.fuzz_rules`: skip `CLEANUP_REPO == "true"`, then run
for merge requests, the default branch and schedules. Other branches and tags
are skipped. Default-branch pipelines replay their own branch slug and enable
report publication; MR and other scheduled pipelines replay `main` and do not
publish reports. To add a development branch, define matching `rules` for both
parent jobs, retaining the default-branch variables if publication is needed.

- `FUZZ_REPLAY_TEMPLATE_REF` is required on the build job. Set it globally as
  shown above to the same ref/SHA as the parent include.
- `FUZZ_REPLAY_TEMPLATE_PROJECT` defaults to
  `deckhouse/3p/deckhouse/modules-gitlab-ci`; override it on `build_fuzz` for a fork.
- `FUZZ_REPLAY_TEMPLATE_FILE` defaults to `/templates/Replay_Fuzz.gitlab-ci.yml`.
- `FUZZ_RUNNER_TAG` defaults to `deckhouse`. Set it globally to choose the runner
  for both the build and the child jobs; parent `default:tags` do not configure
  the child pipeline.
- `FUZZ_S3_REPOSITORY` defaults to `CI_PROJECT_NAME`.
- `FUZZ_S3_BRANCH_SLUG` defaults to `main`; default-branch rules set it to
  `CI_COMMIT_REF_SLUG`. For another baseline, set it on `replay_fuzz`.
- `FUZZ_PUBLISH_REPORT` defaults to `"false"`; default-branch rules set it to
  `"true"`. Set it on `replay_fuzz` when using custom rules.
- Child jobs use `VAULT_SERVER_URL=https://seguro.flant.com`,
  `VAULT_AUTH_PATH=fox` and `VAULT_AUTH_ROLE=dh-${CI_PROJECT_NAME}`. Overrides
  should be global or on `replay_fuzz` so they are forwarded to the child.

GitLab's matching `rules:variables` override job YAML variables. When changing
the default-branch corpus or publication policy, override the matching rules in
both jobs as well. Variables set only on `build_fuzz` are not forwarded by the
sibling `replay_fuzz` trigger. Manual/scheduled pipeline variables are not
forwarded by default; opt into `trigger:forward:pipeline_variables` if needed.

## Project and runner requirements

- The project's existing `before_script` must prepare werf (or the delivery-kit
  version required by its image definitions), registry authentication and any
  build inputs. `Setup.gitlab-ci.yml` supplies the standard werf setup; projects
  using delivery-kit should retain their own setup. Merely setting
  `DELIVERY_KIT_VERSION` does not change this repository's standard setup.
- Provide `MODULES_MODULE_SOURCE`, `MODULES_MODULE_NAME`, `SOURCE_REPO` and
  registry credentials as for a normal module build. `SOURCE_REPO` uses the
  existing `git@host:path`/`host:path` format. Fuzz images are pushed to
  `WERF_REPO` even for MRs, because replay runs on separate runners.
- Build runners need Bash 4+, werf and jq. Replay/publish runners need Bash,
  Docker, jq and access to the image registry. Publication uses a local Docker
  daemon with access to `CI_PROJECT_DIR` for the report bind mount.
- Fuzz images must run as `linux/amd64`, contain Bash 4+, Go, Task, jq, AWS CLI,
  the CA bundle at `/etc/ssl/certs/ca-certificates.crt`, and writable sources with
  a `Taskfile` exposing `fuzz:list`. The image working directory must be its Go
  module. Existing S3 source-path and duplicate-target naming are preserved.
- The GitLab runner/Vault integration must allow the child jobs to fetch
  `FUZZ_S3_ENDPOINT`, `FUZZ_S3_ACCESS_KEY`, and `FUZZ_S3_SECRET_KEY` from the
  existing team fuzzing secret. Build itself does not fetch these secrets.
- The GitLab instance must support `needs:pipeline:job` for parent artifacts,
  dynamic child pipelines and parallel matrices. One matrix entry is generated
  per fuzz image, subject to the instance's matrix limit.

`Build_Fuzz_Images.gitlab-ci.yml` and its `.build_fuzz_dev`/`.build_fuzz_main`
jobs remain available for the older in-image replay flow. Their behaviour and
names are unchanged; use the new pair for separate build and replay steps.
