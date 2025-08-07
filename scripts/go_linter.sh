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

unique_index=0
section_start() {
    local section_title="${1}"
    local section_description="${2}"
    
    if [ "$GITLAB_CI" == "true" ]; then
        unique_index=$((unique_index + 1))
        echo -e "section_start:`date +%s`:${section_title}_${unique_index}[collapsed=true]\r\e[0K${section_description}"
    else
        echo "$section_description"
    fi
}

section_end() {
    local section_title="${1}"
    if [ "$GITLAB_CI" == "true" ]; then
        echo -e "section_end:`date +%s`:${section_title}_${unique_index}\r\e[0K"
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
            section_start "run_lint" "Running linter in $dir (edition: $edition) for $run_for"
            ../../golangci-lint run ${NEW_FROM_REV_ARG} --fix --color=always --allow-parallel-runners --build-tags $edition
            section_end "run_lint"
            if [ $? -ne 0 ]; then
                echo "Linter failed in $dir (edition: $edition) for $run_for"
                failed='true'
            fi
        done

        cd - > /dev/null
    done


    if [[ -n "$(git status --porcelain --untracked-files=no)" ]]; then
        section_start "print_patch" "Linter suggested change for $run_for"
        echo "git apply - <<EOF
$(git diff)
EOF"
        section_end "print_patch" 
        git checkout -f
        failed='true'
    fi
}

NEW_FROM_REV_ARG=""
run_linters "all files"

if [ -n "$CI_MERGE_REQUEST_TARGET_BRANCH_NAME" ]; then
    NEW_FROM_REV_ARG="--new-from-rev $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
    run_linters "changes from $CI_MERGE_REQUEST_TARGET_BRANCH_NAME"
fi

rm golangci-lint

if [ $failed == 'true' ]; then
    exit 1
fi