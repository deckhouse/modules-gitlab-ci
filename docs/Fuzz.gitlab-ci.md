# Fuzz build and corpus replay

`Build_Fuzz.gitlab-ci.yml` and `Replay_Fuzz.gitlab-ci.yml` extract the flow from
`operator-argo`, branch `internal-migrate-to-delivery-kit`, commit `f3cd709`.
Include `Build_Fuzz` in a project and define two jobs:

```yaml
include:
  - project: deckhouse/3p/deckhouse/modules-gitlab-ci
    ref: &fuzz_templates_ref fuzz-replay-engines
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
3. Replay downloads minimized and recovery corpus seeds from
   `s3://anomaloys-materials/<repository>/<branch>/<component>/` and discovers
   targets with `task fuzz:list`. Each matrix job reads its image label
   `io.deckhouse.fuzz.engine` (`go`, `ruzzy` or `afl`). For older images without
   the label, replay uses the image environment variable `FUZZ_ENGINE`, defaulting
   to Go when it is absent. Unsupported engines fail before replay. Ruby/Ruzzy
   and C/C++/AFL images use the task contracts below.
   Go replay also downloads Go cache seeds, copies the seeds to `testdata/fuzz`,
   and runs each target with `go test -run`, without starting a fuzzing campaign.
   Each input (including `F.Add` seeds) has a separate 30-second deadline.
   The supervisor starts the deadline on the input's Go JSON `run` event, so
   compilation and the cumulative time of other inputs do not consume it.
   Nested `t.Run` calls remain within the same input's deadline. A timeout fails
   the target, retaining its input name and stack diagnostics; replay then
   continues with the other targets.
4. Failed targets retain logs, corpus files and reproduction
   commands under `fuzz-replay/`. The summary and diagnostics are collected from
   the stopped container, uploaded even on failure, and retained for seven days.
   Go reports also include JSON test events; Ruzzy reports include crash
   artifacts written by the replay task. AFL reports retain per-input maps and
   a list of inputs with missing or empty maps.
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
- `FUZZ_REPLAY_INPUT_TIMEOUT` applies to Go replay and defaults to `"30s"`,
  matching the fuzzing system's per-input replay limit. It must be a positive
  Go duration. Set it globally or on the parent `replay_fuzz` trigger to
  override it. Generated reproduction
  commands use the same timeout while selecting a single failed input.
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
- Fuzz images must run as `linux/amd64`, contain Bash 4+, Task, jq, AWS CLI,
  the CA bundle at `/etc/ssl/certs/ca-certificates.crt`, and writable sources with
  a `Taskfile` exposing `fuzz:list`.
- Go images must contain Go and use their Go module as the working directory.
  Existing S3 source-path and duplicate-target naming are preserved.
- AFL and Ruzzy images need `sha256sum` and `find` to stage their corpus.
- AFL images must contain AFL++ and instrumented binaries, and provide the
  batch replay contract below. Arbitrary C/C++ binaries or libFuzzer-only
  images cannot use the AFL contract.
- Ruzzy images must contain Ruby and Ruzzy, use their application directory as
  the working directory, and provide the JSONL discovery and replay task
  contract described below. The image and task supply any required local
  application services.
- The GitLab runner/Vault integration must allow the child jobs to fetch
  `FUZZ_S3_ENDPOINT`, `FUZZ_S3_ACCESS_KEY`, and `FUZZ_S3_SECRET_KEY` from the
  existing team fuzzing secret. Build itself does not fetch these secrets.
- The GitLab instance must support `needs:pipeline:job` for parent artifacts,
  dynamic child pipelines and parallel matrices. One matrix entry is generated
  per fuzz image, subject to the instance's matrix limit.

`Build_Fuzz_Images.gitlab-ci.yml` and its `.build_fuzz_dev`/`.build_fuzz_main`
jobs remain available for the older in-image replay flow. Their behaviour and
names are unchanged; use the new pair for separate build and replay steps.

## Ruzzy replay contract

Set the image label `io.deckhouse.fuzz.engine=ruzzy`; the shared
`ci-images/fuzz-ruzzy` base also sets the legacy `FUZZ_ENGINE=ruzzy` environment
variable. `task fuzz:list` must emit one JSON object per line with
nonempty string fields `package` and `target`, for example:

```json
{"package":"backend","target":"jwt_header_decoder"}
{"package":"backend","target":"cancan_ability"}
```

Target names contain only letters, digits and underscores, and must be unique
within the image because they identify S3 corpus directories. Package names
must not contain NUL, tabs or line breaks.

For each target, replay invokes `task fuzz:replay` with `FUZZ_PKG`,
`FUZZ_TARGET`, `FUZZ_CORPUS_DIR` and `FUZZ_ARTIFACT_DIR`. The corpus directory
contains the merged, flat corpus described below and may be empty. The task
can add application-specific seeds, prepares dependencies and replays inputs
without generating new ones. It returns a nonzero status on failure
and writes crash inputs to `FUZZ_ARTIFACT_DIR`. S3 credentials are removed
before discovery and target execution. All targets are attempted; failed
targets retain logs, downloaded corpus, crash artifacts and a reproduction
command in the job artifacts. Built-in seeds remain in the same image used by
the reproduction command.

Ruzzy execution limits are owned by the image's `fuzz:replay` task;
`FUZZ_REPLAY_INPUT_TIMEOUT` configures only the Go supervisor.


## Shared AFL and Ruzzy corpus staging

Replay combines S3 `<target>/corpus/minimized` and `recovery` with the image's
built-in seeds. Image seed locations follow the fuzzing system contract:

- `FUZZ_SEEDS/<target>` when `FUZZ_SEEDS` is set.
- `FUZZ_SEED_DIR`, `SEED_CORPUS_DIR`, `INPUT_CORPUS_DIR` and `FUZZ_CORPUS`;
  `{target}` and `{package}` placeholders are expanded.
- Under the image working directory: `testdata/fuzz/<target>`, `corpus/<target>`,
  `seeds/<target>`, `testdata/<target>`, `fuzz/seeds/<target>` and
  `fuzz/corpus/<target>`.

Directories are read recursively; AFL `.state` directories and `README.txt`
bookkeeping files are excluded. Inputs are named by SHA-256 in a temporary
flat directory. Identical contents are replayed once; different contents with
the same original basename are both retained. Empty files are preserved.
For failed targets, `corpus-sources.tsv` maps each hash to its original path
(shell-escaped), and `corpus/` contains exactly the staged inputs.

## AFL replay contract (C/C++)

Set `io.deckhouse.fuzz.engine=afl` on the image. Its silent `task fuzz:list`
must print target basenames, one per line, such as `nginx_conf_parse`. Names
start with a letter or underscore and otherwise contain letters, digits,
underscores, dots, plus signs or hyphens. Duplicate lines are deduplicated;
empty or malformed discovery fails the job.

Shared replay calls **one `task fuzz:replay` per target**, with `FUZZ_TARGET`,
`FUZZ_PKG=afl`, `FUZZ_INPUT_DIR`, `FUZZ_CORPUS_DIR` and `FUZZ_ARTIFACT_DIR`.
Both input-directory variables point to the same flat corpus. The task owns
the target's exact argv, sanitizer configuration and execution timeout. It
must run batch `afl-showmap -Z -i "$FUZZ_INPUT_DIR" -o "$FUZZ_ARTIFACT_DIR/maps"`
with one reusable forkserver, leave those maps in the artifact directory, and
fail if any input has a missing/empty map or showmap itself fails.

`-Z` uses AFL++'s cmin map format: crashes and timeouts leave empty map files
when `AFL_CMIN_ALLOW_ANY` and `AFL_CMIN_CRASHES_ONLY` are **unset**. The shared
job checks every expected map as well, because showmap's final exit status
can describe only the last input. A cumulative `-C` map alone is insufficient.
The behavior was verified against the AFL++ v5.03c source and executed with
v5.03a; preserve these semantics when updating the image's AFL++ version.

Shared AFL replay enables `AFL_DEBUG_CHILD=1`, `AFL_PRINT_FILENAMES=1` and
`AFL_DEBUG=1` **inside the container**, so child stdout/stderr, sanitizer reports,
input filenames and AFL startup/crash diagnostics reach the job log. Removing
`-q` alone is insufficient: `-Z` enables quiet mode itself. Replay does not dump
the environment or read corpus contents into the log; image tasks should avoid
logging credentials or input data in their own diagnostics.

`afl-tool.log` records the tool path/version. Each target's `replay.log` records
the engine, task command, input count, task/pipeline exit code and map totals;
`maps.tsv` records `present`, `empty` or `missing` for each input. These logs are
retained on success as well as failure. Image adapters should also log their
actual showmap command, timeout and numeric exit status, and preserve child
output. Batch showmap's status describes the last input, not the entire corpus;
exit 1 may also be a tool/startup error, so consult the diagnostics. Missing or
empty maps alone must not be reported as confirmed crashes or timeouts.

For an instrumented binary that takes an input filename, the image task can use:

```yaml
version: '3'
silent: true
tasks:
  fuzz:replay:
    cmds:
      - |
        set -eu
        subject="/out/fuzz/bin/${FUZZ_TARGET:?}"
        input_dir="${FUZZ_INPUT_DIR:?}"
        maps="${FUZZ_ARTIFACT_DIR:?}/maps"
        test -x "$subject"
        mkdir -p "$maps"  # Must be empty at the start of this replay.
        unset AFL_CMIN_ALLOW_ANY AFL_CMIN_CRASHES_ONLY
        status=0
        afl-showmap -q -Z -m none -t 30000 -i "$input_dir" -o "$maps" \
          -- "$subject" @@ || status=$?
        count=0
        for seed in "$input_dir"/*; do
          test -f "$seed" || continue
          count=$((count + 1))
          test -s "$maps/${seed##*/}" || status=1
        done
        test "$count" -gt 0 && test "$status" -eq 0
```

The example uses 30 seconds per input. Keep package-specific flags in the
image Taskfile; a stdin target needs its own argv instead of `@@`. Sanitizer
errors must terminate the target as a crash (for example, ASan/UBSan
`abort_on_error=1`). A normal nonzero target exit is not necessarily an AFL
crash; use the image's AFL crash-exit configuration if required by the harness.
The image must reject inputs larger than its supported size rather than let
showmap silently truncate them.

No corpus inputs is an error. AFL++ v5.03 skips zero-byte inputs in batch
mode; the resulting missing map fails shared replay as incomplete. Such an
input is retained for investigation instead of silently counted as passing.
A missing/empty map identifies an unsuccessful input, but does not distinguish
crash from timeout or missing instrumentation. All other targets still run;
failed targets retain the merged corpus, maps, logs, failed-input list and
reproduction command for seven days. This replays existing inputs only and
does not start `afl-fuzz` or a mutation campaign.
