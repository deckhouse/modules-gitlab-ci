#!/usr/bin/env python3
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
# Translates Russian changelog (.ru.yml) to English (.yml).
# Finds latest vX.Y.Z.ru.yml, creates vX.Y.Z.yml if missing.
# Usage: translate_changelog.py [CHANGELOG_DIR]
# Exit 0 if nothing to do or success; exit 1 on error.

import os
import re
import sys
from pathlib import Path
from typing import Optional, Tuple

from packaging import version as pkg_version


def find_latest_ru_changelog(changelog_dir: str) -> Optional[Tuple[str, str, str]]:
    """Find latest Russian changelog. Returns (version, ru_file, eng_file) or None."""
    path = Path(changelog_dir)
    if not path.exists():
        return None
    ru_files = list(path.glob("v*.ru.yml"))
    if not ru_files:
        return None
    # Parse version from filename vX.Y.Z.ru.yml
    versions = []
    for f in ru_files:
        m = re.match(r"v(\d+\.\d+\.\d+)\.ru\.yml", f.name)
        if m:
            try:
                ver = pkg_version.parse(m.group(1))
                versions.append((ver, f.name))
            except pkg_version.InvalidVersion:
                continue
    if not versions:
        return None
    versions.sort(reverse=True, key=lambda x: x[0])
    latest_ver, ru_name = versions[0]
    version_str = f"v{latest_ver}"
    eng_name = ru_name.replace(".ru.yml", ".yml")
    eng_path = path / eng_name
    if eng_path.exists():
        return None  # English already exists, nothing to do
    return (version_str, ru_name, eng_name)


def translate_file(ru_path: Path, eng_path: Path) -> None:
    """Translate Russian YAML changelog to English line by line, preserving format."""
    try:
        from deep_translator import GoogleTranslator
    except ImportError:
        print("Error: deep_translator not installed. pip install deep-translator", file=sys.stderr)
        sys.exit(1)

    translator = GoogleTranslator(source="ru", target="en")
    with open(ru_path, "r", encoding="utf-8") as f:
        ru_lines = f.readlines()

    with open(eng_path, "w", encoding="utf-8") as f:
        for line in ru_lines:
            if not line.strip():
                f.write(line)
                continue
            indent_len = len(line) - len(line.lstrip())
            content = line.strip()
            try:
                translated = translator.translate(content)
            except Exception as e:
                print(f"Warning: translation failed for '{content[:50]}...': {e}", file=sys.stderr)
                translated = content
            f.write(" " * indent_len + translated + "\n")

    print(f"Translated {ru_path.name} -> {eng_path.name}")


def main() -> int:
    changelog_dir = sys.argv[1] if len(sys.argv) > 1 else "CHANGELOG"
    if not os.path.isdir(changelog_dir):
        print(f"Changelog dir not found: {changelog_dir}", file=sys.stderr)
        return 1

    result = find_latest_ru_changelog(changelog_dir)
    if not result:
        print("No Russian changelog to translate (or English already exists).")
        return 0

    version_str, ru_name, eng_name = result
    ru_path = Path(changelog_dir) / ru_name
    eng_path = Path(changelog_dir) / eng_name

    translate_file(ru_path, eng_path)
    # Print for CI (version, ru_file, eng_file)
    print(f"VERSION={version_str}")
    print(f"RU_FILE={ru_name}")
    print(f"ENG_FILE={eng_name}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
