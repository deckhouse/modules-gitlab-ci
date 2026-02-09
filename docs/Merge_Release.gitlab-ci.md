# Merge MR and Create Release

## Description

This template implements the same flow as [modules-actions merge-and-release](https://github.com/deckhouse/modules-actions/tree/main/merge-and-release) for GitLab:

1. **Trigger:** Add label `release` or `ready-for-release` to a Merge Request and run the pipeline (or re-run after adding the label).
2. **Version:** Extracted from the MR title (e.g. `v0.3.17` or `0.3.17`).
3. **Merge:** MR is merged via GitLab API (squash, delete source branch).
4. **Tag:** A tag is created on the base branch and pushed (this triggers tag pipelines, e.g. Build/Deploy).
5. **Release:** GitLab Release is created with description from `CHANGELOG/<version>.yml`.

## Variables

### Mandatory (CI/CD variable, masked)

- **RELEASE_TOKEN** — GitLab token with `api` and `write_repository` (Personal Access Token or Project Access Token). Used to merge MR, push tag, and create release.

### Optional

- **MERGE_RELEASE_CHANGELOG_PATH** — Path to CHANGELOG directory. Default: `CHANGELOG`.
- **MERGE_RELEASE_BASE_BRANCH** — Base branch to merge into. Default: `main`.

## Usage

1. Include the template in your `.gitlab-ci.yml`:
   ```yaml
   include:
     - remote: 'https://raw.githubusercontent.com/deckhouse/modules-gitlab-ci/refs/heads/main/templates/Merge_Release.gitlab-ci.yml'
   ```

2. Add a job that extends `.merge_and_release`:
   ```yaml
   Merge and Release:
     extends: .merge_and_release
   ```

3. In your Merge Request:
   - Set the title to include the version (e.g. `Release v0.3.17` or `v0.3.17`).
   - Add the label `release` or `ready-for-release`.
   - Run the pipeline (or re-run after adding the label).

4. Ensure `RELEASE_TOKEN` is set in the project’s CI/CD variables (masked).

## Example

See [`examples/merge-and-release.gitlab-ci.yml`](../examples/merge-and-release.gitlab-ci.yml).
