#!/usr/bin/env bash
# Copyright 2025 Flant JSC
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# Merge MR and Create Release — GitLab analogue of modules-actions merge-and-release.
# Merges a Merge Request (squash, delete branch), creates a tag, pushes it, creates GitLab Release with changelog.

set -euo pipefail

# Required: passed from GitLab CI
PR_TITLE="${1:-$CI_MERGE_REQUEST_TITLE}"
MR_IID="${2:-$CI_MERGE_REQUEST_IID}"
CHANGELOG_PATH="${3:-CHANGELOG}"
BASE_BRANCH="${4:-main}"
# Token: RELEASE_TOKEN or CI_JOB_TOKEN (for merge; push/release may need RELEASE_TOKEN with api, write_repository)
GITLAB_TOKEN="${RELEASE_TOKEN:-$CI_JOB_TOKEN}"
API_URL="${CI_API_V4_URL}"
PROJECT_ID="${CI_PROJECT_ID}"
# PROJECT_PATH for git clone (URL-encoded path for API is fine; for clone use CI_REPOSITORY_URL with token)
REPO_URL="${CI_REPOSITORY_URL}"

# --- Extract version from MR title (e.g. v0.3.17 or 0.3.17)
VERSION=$(echo "$PR_TITLE" | grep -oE 'v?[0-9]+\.[0-9]+\.[0-9]+' | head -1)
if [ -z "$VERSION" ]; then
  echo "Error: Could not extract version from MR title: $PR_TITLE"
  exit 1
fi
if [[ ! "$VERSION" =~ ^v ]]; then
  VERSION="v${VERSION}"
fi
echo "Extracted version: $VERSION"

# --- Merge MR via GitLab API (squash, remove source branch)
echo "Merging MR !${MR_IID} (squash, delete source branch)..."
MERGE_RESPONSE=$(curl -s -w "\n%{http_code}" --request PUT \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --header "Content-Type: application/json" \
  "${API_URL}/projects/${PROJECT_ID}/merge_requests/${MR_IID}/merge?squash=true&should_remove_source_branch=true")
HTTP_BODY=$(echo "$MERGE_RESPONSE" | head -n -1)
HTTP_CODE=$(echo "$MERGE_RESPONSE" | tail -n 1)
if [ "$HTTP_CODE" != "200" ]; then
  echo "Merge failed (HTTP $HTTP_CODE): $HTTP_BODY"
  exit 1
fi
echo "MR merged successfully."

# --- Wait for merge to complete
sleep 10

# --- Clone repo (fresh clone to get post-merge state), checkout base branch, create tag, push
# Use token in URL for push (CI_SERVER_HOST, CI_PROJECT_PATH are set in GitLab CI)
REPO_URL_WITH_TOKEN="https://oauth2:${GITLAB_TOKEN}@${CI_SERVER_HOST}/${CI_PROJECT_PATH}.git"

git config --global user.email "gitlab-ci@gitlab.com"
git config --global user.name "GitLab CI"
git clone --branch "$BASE_BRANCH" --single-branch --depth 50 "$REPO_URL_WITH_TOKEN" /tmp/repo_release
cd /tmp/repo_release
git fetch origin "$BASE_BRANCH"
git reset --hard "origin/${BASE_BRANCH}"

if git rev-parse "$VERSION" >/dev/null 2>&1; then
  echo "Tag $VERSION already exists, skipping tag creation."
else
  git tag -a "$VERSION" -m "Release $VERSION"
  git push origin "$VERSION"
  echo "Tag $VERSION created and pushed."
fi

# --- Read changelog for release description
CHANGELOG_FILE="${CHANGELOG_PATH}/${VERSION}.yml"
RELEASE_DESCRIPTION="Release $VERSION"
if [ -f "$CHANGELOG_FILE" ]; then
  RELEASE_DESCRIPTION="## Changelog

\`\`\`yaml
$(cat "$CHANGELOG_FILE")
\`\`\`"
else
  echo "Warning: Changelog file $CHANGELOG_FILE not found, using default description."
fi

# --- Create GitLab Release via API
# POST /projects/:id/releases — tag_name, name, description
RELEASE_PAYLOAD=$(jq -n \
  --arg tag_name "$VERSION" \
  --arg name "$VERSION" \
  --arg description "$RELEASE_DESCRIPTION" \
  '{ tag_name: $tag_name, name: $name, description: $description }')
RELEASE_RESPONSE=$(curl -s -w "\n%{http_code}" --request POST \
  --header "PRIVATE-TOKEN: ${GITLAB_TOKEN}" \
  --header "Content-Type: application/json" \
  --data "$RELEASE_PAYLOAD" \
  "${API_URL}/projects/${PROJECT_ID}/releases")
RELEASE_HTTP_BODY=$(echo "$RELEASE_RESPONSE" | head -n -1)
RELEASE_HTTP_CODE=$(echo "$RELEASE_RESPONSE" | tail -n 1)
if [ "$RELEASE_HTTP_CODE" != "201" ] && [ "$RELEASE_HTTP_CODE" != "200" ]; then
  echo "Create release failed (HTTP $RELEASE_HTTP_CODE): $RELEASE_HTTP_BODY"
  exit 1
fi
echo "GitLab Release created for $VERSION."
