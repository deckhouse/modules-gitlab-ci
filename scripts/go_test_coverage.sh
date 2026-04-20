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

# Force the toolchain selected by `go.mod` to be downloaded for every module
# we touch. The runner ships a Go distribution (longsleep PPA on Ubuntu) that
# strips `covdata` and several other tools from `$GOROOT/pkg/tool/...`. Plain
# `GOTOOLCHAIN=auto` keeps such a stripped local toolchain whenever it
# satisfies the `go` directive, and `go test ... -cover` then fails with
# `go: no such tool "covdata"` for packages that have no `*_test.go` files.
# Setting GOTOOLCHAIN=goX.Y.Z (without the `+auto` suffix) makes the `go`
# command always fetch the official upstream toolchain, which includes
# `covdata`. The downloaded archive is cached under
# `$GOMODCACHE/golang.org/toolchain` and reused by subsequent jobs.
export GOTOOLCHAIN=auto

# Print a GOTOOLCHAIN value (e.g. goX.Y.Z) derived from the `go` directive
# in the given go.mod, or empty if no usable version can be parsed.
mod_go_toolchain() {
    local gomod="$1"
    local v
    v=$(awk '$1 == "go" && $2 ~ /^[0-9]+\.[0-9]+(\.[0-9]+)?$/ {print $2; exit}' "$gomod")
    if [ -z "$v" ]; then
        return
    fi
    case "$v" in
        *.*.*) ;;
        *) v="${v}.0" ;;
    esac
    printf 'go%s\n' "$v"
}

if [ ! -d "images" ]; then
    echo "No images/ directory found. Please run this script from the root of the repository."
    exit 1
fi

find images/ -type f -name "go.mod" | while read -r gomod; do
    dir=$(dirname "$gomod")

    echo "Test coverage in $dir"

    cd "$dir" || continue

    toolchain=$(mod_go_toolchain go.mod)
    if [ -n "$toolchain" ]; then
        export GOTOOLCHAIN="$toolchain"
        echo "  Using GOTOOLCHAIN=$toolchain (forced download to get a complete Go SDK with 'covdata')"
    else
        export GOTOOLCHAIN=auto
        echo "  Could not parse 'go' directive from $dir/go.mod; falling back to GOTOOLCHAIN=auto"
    fi

    for tag in $GO_BUILD_TAGS; do
        echo "  Build tag: $tag"

        go test ./... -cover -tags "$tag"
    done

    cd - > /dev/null

    echo "----------------------------------------"
done