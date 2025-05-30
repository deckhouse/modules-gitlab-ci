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

if [ ! -d "images" ]; then
    echo "No images/ directory found. Please run this script from the root of the repository."
    exit 1
fi

find images/ -type f -name "go.mod" | while read -r gomod; do
    dir=$(dirname "$gomod")
    
    echo "Test coverage in $dir"
    
    cd "$dir" || continue
    
    for tag in $GO_BUILD_TAGS; do
        echo "  Build tag: $tag"
        
        go test ./... -cover -tags "$tag" 
    done
    
    cd - > /dev/null
    
    echo "----------------------------------------"
done