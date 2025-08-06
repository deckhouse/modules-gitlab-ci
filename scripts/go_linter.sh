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

curl -sSfL https://raw.githubusercontent.com/golangci/golangci-lint/master/install.sh | sh -s -- -b . v1.64.5

basedir=$(pwd)
failed='false'

for i in $(find images -type f -name go.mod);do
    dir=$(echo $i | sed 's/go.mod$//')
    cd $basedir/$dir
    # check all editions
    for edition in $GO_BUILD_TAGS ;do
        echo "Running linter in $dir (edition: $edition)"
        ../../golangci-lint run --allow-parallel-runners --build-tags --fix $edition
        if [ $? -ne 0 ]; then
        echo "Linter failed in $dir (edition: $edition)"
        failed='true'
        fi
    done

    cd - > /dev/null
done

rm golangci-lint

if [ $failed == 'true' ]; then
    echo "To apply fix run:
git patch - <<EOF
$(git diff) 
EOF"
    exit 1
fi