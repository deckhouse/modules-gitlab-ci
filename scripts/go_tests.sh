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

basedir=$(pwd)
failed='false'

# Iterate over Go modules (one go.mod per module) instead of every *_test.go
# file. The previous implementation ran `go test` once per test file in the
# enclosing package, which produced N*M duplicate runs for a package with N
# test files and M build tags. Iterating over go.mod files runs each module
# exactly once per build tag, and `./...` covers every package inside.
for gomod in $(find images -type f -name 'go.mod'); do
    dir=$(dirname "$gomod")
    cd "$basedir/$dir" || continue
    # check all editions
    for edition in $GO_BUILD_TAGS; do
        echo "Running tests in $dir (edition: $edition)"
        go test -v -tags "$edition" ./...
        if [ $? -ne 0 ]; then
            echo "Tests failed in $dir (edition: $edition)"
            failed='true'
        fi
    done
    cd "$basedir" || exit 1
done

if [ "$failed" = 'true' ]; then
    exit 1
fi