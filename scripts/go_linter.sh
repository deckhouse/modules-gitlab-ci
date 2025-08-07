#!/bin/bash

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

section_start() {
    local section_title="${1}"
    local section_description="${2:-$section_title}"
    
    if [ "$GITLAB_CI" == "true" ]; then
        echo -e "section_start:`date +%s`:${section_title}[collapsed=true]\r\e[0K${section_description}"
    else
        echo "$section_description"
    fi
}

section_end() {
    local section_title="${1}"
    if [ "$GITLAB_CI" == "true" ]; then
        echo -e "section_end:`date +%s`:${section_title}\r\e[0K"
    fi
}

linter_version="v1.64.5"
section_start "install_linter" "Installing golangci-lint@$linter_version"
curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b . $linter_version
section_end "install_linter"

basedir=$(pwd)
failed='false'

run_linters() {
    local run_for="${1}"
    for i in $(find images -type f -name go.mod);do
        dir=$(echo $i | sed 's/go.mod$//')
        cd $basedir/$dir
        # check all editions
        for edition in $GO_BUILD_TAGS ;do
            section_start "run_lint_$dir_$edition_$run_for" "Running linter in $dir (edition: $edition) for $run_for"
            ../../golangci-lint run ${NEW_FROM_REV_ARG} --fix --color=always --allow-parallel-runners --build-tags $edition
            section_end "run_lint_$dir_$edition_$run_for"
            if [ $? -ne 0 ]; then
                echo "Linter failed in $dir (edition: $edition) for $run_for"
                failed='true'
            fi
        done

        cd - > /dev/null
    done


    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
        section_start "print_patch_$run_for" "Linter suggested change"
        echo "To apply suggested changes run:
git apply - <<EOF
$(git diff)
EOF"
        section_end "print_patch_$run_for" 
        git checkout -f
        failed='true'
    fi
}

NEW_FROM_REV_ARG=""
run_linters "all files"

if [ -n "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" ]; then
    NEW_FROM_REV_ARG="--new-from-rev $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
    echo -e "\e[0;32mRunning linters for changes from revision $CI_MERGE_REQUEST_TARGET_BRANCH_NAME\e[0m"
    run_linters "changes from $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
fi

rm golangci-lint

if [ $failed == 'true' ]; then
    exit 1
fi