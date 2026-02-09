# Translate Changelog and Create MR

## Description

This template implements the same flow as [modules-actions translate-changelog](https://github.com/deckhouse/modules-actions/tree/main/translate-changelog) for GitLab:

1. **Trigger:** Pipeline runs on **push** to any branch except the default branch.
2. **Check:** If the last commit changed any `CHANGELOG/*.ru.yml` file.
3. **Translate:** Finds the latest Russian changelog (`vX.Y.Z.ru.yml` by semver). If the corresponding English file (`.yml`) does not exist, translates it line-by-line (Google Translate) and writes `vX.Y.Z.yml`.
4. **Commit & push:** Commits the new/updated English changelog and pushes to the current branch.
5. **Create MR:** Creates a Merge Request to the base branch with title = version (e.g. `v0.3.17`) and a description that includes the changelog content. If an MR from this branch to the base branch already exists, it is skipped.

## Variables

### Optional

- **TRANSLATE_CHANGELOG_PATH** — Path to the CHANGELOG directory. Default: `CHANGELOG`.
- **TRANSLATE_BASE_BRANCH** — Target branch for the MR. Default: `main`.
- **RELEASE_TOKEN** — GitLab token with `api` and `write_repository` (for push and create MR). If not set, `CI_JOB_TOKEN` is used (works in GitLab 15.9+ for same project).

## Usage

1. Include the template in your `.gitlab-ci.yml`:
   ```yaml
   include:
     - remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/main/templates/Translate_Changelog.gitlab-ci.yml'
   ```

2. Add a job that extends `.translate_and_create_mr`:
   ```yaml
   Translate changelog and create MR:
     extends: .translate_and_create_mr
   ```

3. Workflow: push a branch that adds or changes a `CHANGELOG/vX.Y.Z.ru.yml` file. The job will translate it to `CHANGELOG/vX.Y.Z.yml`, commit, push, and open an MR to the base branch.

## Example

See [`examples/translate-changelog.gitlab-ci.yml`](../examples/translate-changelog.gitlab-ci.yml).
