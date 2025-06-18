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

search_dir=$(pwd)"/images"

if [ ! -d "$search_dir" ]; then
echo "Directory $search_dir does not exist."
exit 1
fi

temp_dir=$(mktemp -d)
touch "$temp_dir/incorrect_alert"

trap 'rm -rf "$temp_dir"' EXIT

find images/ -type f -name "go.mod" | while read -r gomod; do
    dir=$(dirname "$gomod")
    
    echo "Checking $dir"
    
    cd "$dir" || continue
    
    go list -m all | grep deckhouse | grep -v '=>' | while IFS= read -r line; do
    module_name=$(echo "$line" | awk '{print $1}')
    module_version=$(echo "$line" | awk '{print $2}')

    if [ -z "$module_version" ]; then
        echo "  Checking module name $module_name"
        GITLAB_REPOSITORY=`echo "$CI_REPOSITORY_URL" | sed 's/.*@//' | sed 's/\.git$//'`
        correct_module_name="$GITLAB_REPOSITORY"/"$dir"
        if [ "$module_name" != "$correct_module_name" ]; then
            echo "  Incorrect module name: $module_name, expected: $correct_module_name"
            echo "  Incorrect module name: $module_name, expected: $correct_module_name" >> "$temp_dir/incorrect_alert"
        else
            echo "  Correct module name: $module_name"
        fi
    else
        echo "  Checking module tag $module_name"
        repository=$(echo "$line" | awk '{print $1}' | awk -F'/' '{ print "https://"$1"/"$2"/"$3".git" }')
        pseudo_tag=$(echo "$line" | awk '{print $2}')
        if [[ $pseudo_tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "  Exact tag in repo $repository: $pseudo_tag, skipping"
            continue
        fi

        echo "  Cloning repo $repository into $temp_dir"
        if [ ! -d "$temp_dir/$repository" ]; then
            git clone "$repository" "$temp_dir/$repository" >/dev/null 2>&1
        fi

        cd "$temp_dir/$repository" || continue
        
        commit_info=$(git log -1 --pretty=format:"%H %cd" --date=iso-strict -- api/*)
        short_hash=$(echo "$commit_info" | awk '{print substr($1,1,12)}')
        commit_date=$(echo "$commit_info" | awk '{print $2}')
        commit_date=$(date -u -d "$commit_date" +"%Y%m%d%H%M%S")
        actual_pseudo_tag="v0.0.0-"$commit_date"-"$short_hash
        pseudo_tag_date=$(echo $pseudo_tag | awk -F'-' '{ print $2 }')
        echo "  Latest commit in $repository: $short_hash $commit_date"
        
        if [[ "$pseudo_tag" != "$actual_pseudo_tag" ]]; then
            echo "  Incorrect pseudo tag for repo $repository in file "$go_mod_file" (current: "$pseudo_tag", actual:"$actual_pseudo_tag")"
            echo "  Incorrect pseudo tag for repo $repository in file "$go_mod_file" (current: "$pseudo_tag", actual:"$actual_pseudo_tag")" >> $temp_dir"/incorrect_alert"
        fi
        
        cd - >/dev/null 2>&1
    fi
    done   
    
    cd - > /dev/null
    
    echo "----------------------------------------"
done

alert_lines_count=$(cat $temp_dir"/incorrect_alert" | wc -l)

if [ $alert_lines_count != 0 ]; then
    echo "We have non-actual pseudo-tags or modules names in repository's go.mod files"
    exit 1
fi
