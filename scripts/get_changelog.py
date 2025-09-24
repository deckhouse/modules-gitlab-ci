#!/usr/bin/env python3
"""
Script for getting changelog of versions newer than the specified module version on the channel.
Uses releases.deckhouse.ru API to get current module versions.
"""

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Tuple
import json

import requests
import yaml
from bs4 import BeautifulSoup


def normalize_channel(channel: str) -> str:
    """
    Converts channel to proper case.
    
    Args:
        channel (str): Source channel
        
    Returns:
        str: Channel in proper case
    """
    channel_mapping = {
        'alpha': 'Alpha',
        'beta': 'Beta', 
        'early-access': 'Early Access',
        'stable': 'Stable',
        'rock-solid': 'Rock Solid'
    }
    
    return channel_mapping.get(channel.lower(), channel)


def send_post_request(url, channel, text):
    """
    Sends POST request with JSON body containing channel and text
    
    Args:
        url (str): URL for the request
        channel (str): Value for the channel field
        text (str): Message text with escaped special characters
    
    Returns:
        dict: Server response in JSON format or None on error
    """   
    # Form request body
    payload = {
        "channel": channel,
        "text": text
    }
    
    # Request headers
    headers = {
        "Content-Type": "application/json"
    }
    
    # Send POST request
    response = requests.post(
        url,
        data=json.dumps(payload),  # Serialize dictionary to JSON
        headers=headers
    )
    
    # Check response status
    response.raise_for_status()  # Will raise exception for 4xx/5xx codes
    
    # Return response in JSON format if available
    return {"status": "success"}



def html_table_to_json(html_content):
    soup = BeautifulSoup(html_content, 'html.parser')
    
    table = soup.find('table')
    if not table:
        return {"error": "Table not found"}
    
    headers = []
    for th in table.find('thead').find_all('th'):
        header_text = th.get_text(strip=True)
        if header_text and header_text != "Модули" and "Вспомогательные модули" not in header_text:
            headers.append(header_text)
    
    result = {
        "deckhouse": {},
        "modules": {},
        "helper_modules": {}
    }
    
    is_helper_modules = False
    
    current_section = "deckhouse"
    for tbody in table.find_all('tbody'):
        for tr in tbody.find_all('tr'):
            cells = tr.find_all('td')
            if cells:
                name = cells[0].get_text(strip=True)
                versions = []
                
                for td in cells[1:]:
                    version = td.find('div') or td.find('span') or td
                    version_text = version.get_text(strip=True)
                    versions.append(version_text)
                
                if current_section == "deckhouse":
                    result["deckhouse"][name] = dict(zip(headers[1:], versions))
                elif is_helper_modules:
                    result["helper_modules"][name] = dict(zip(headers[1:], versions))
                else:
                    result["modules"][name] = dict(zip(headers[1:], versions))
        
        next_thead = tbody.find_next('thead')
        if next_thead and "Модули" in next_thead.get_text():
            current_section = "modules"
        elif next_thead and "Вспомогательные модули" in next_thead.get_text():
            current_section = "helper_modules"
            is_helper_modules = True
    
    return result


def parse_version(version: str) -> Tuple[int, int, int]:
    """Parses version in vX.Y.Z format into tuple (X, Y, Z)."""
    # Remove 'v' prefix if present
    version = version.lstrip('v')
    
    # Split into parts
    parts = version.split('.')
    if len(parts) != 3:
        raise ValueError(f"Invalid version format: {version}")
    
    try:
        return (int(parts[0]), int(parts[1]), int(parts[2]))
    except ValueError:
        raise ValueError(f"Invalid version format: {version}")


def compare_versions(version1: str, version2: str) -> int:
    """
    Compares two versions.
    Returns:
    -1 if version1 < version2
     0 if version1 == version2
     1 if version1 > version2
    """
    v1 = parse_version(version1)
    v2 = parse_version(version2)
    
    if v1 < v2:
        return -1
    elif v1 > v2:
        return 1
    else:
        return 0


def get_module_version_from_channel(module_name: str, channel: str) -> Optional[str]:
    """Gets module version from the specified channel."""
    try:
        response = requests.get('https://releases.deckhouse.ru/fe')
        response.raise_for_status()
        
        releases_data = html_table_to_json(response.text)
        
        # Normalize channel name
        normalized_channel = normalize_channel(channel)
        
        # Search for module in different sections
        for section_name in ['modules', 'helper_modules']:
            if module_name in releases_data[section_name]:
                version = releases_data[section_name][module_name].get(normalized_channel)
                if version:
                    return version
        
        return None
        
    except Exception as e:
        print(f"Error getting module version: {e}", file=sys.stderr)
        return None


def get_changelog_files(module_path: str) -> List[Tuple[str, str]]:
    """
    Gets list of changelog files for the module.
    Returns list of tuples (version, file_path).
    Priority is given to Russian versions of files (.ru.yml).
    """
    changelog_dir = Path(module_path) / "CHANGELOG"
    if not changelog_dir.exists():
        return []
    
    changelog_files = []
    
    # Search for files in vX.Y.Z.yml and vX.Y.Z.ru.yml format
    pattern = re.compile(r'^v(\d+\.\d+\.\d+)\.ru\.yml$')
    pattern_en = re.compile(r'^v(\d+\.\d+\.\d+)\.yml$')
    
    # First collect Russian files
    for file_path in changelog_dir.glob('v*.ru.yml'):
        match = pattern.match(file_path.name)
        if match:
            version = f"v{match.group(1)}"
            changelog_files.append((version, str(file_path)))
    
    # Then add English files if no Russian version exists
    for file_path in changelog_dir.glob('v*.yml'):
        match = pattern_en.match(file_path.name)
        if match:
            version = f"v{match.group(1)}"
            # Check if Russian version already exists for this version
            if not any(v == version for v, _ in changelog_files):
                changelog_files.append((version, str(file_path)))
    
    return changelog_files


def read_changelog(file_path: str) -> str:
    """Reads changelog file content."""
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            content = yaml.safe_load(f)
            
        # Format changelog for output
        if isinstance(content, dict):
            # Check Russian keys
            if 'Изменения' in content.keys():
                changes = content['Изменения']
            elif 'Changes' in content.keys():
                changes = content['Changes']
            else:
                return str(content)

            return(changes)
                
        else:
            return str(content)
            
    except Exception as e:
        return f"File reading error: {e}"


def get_latest_tag_from_changelogs(module_path: str) -> Optional[str]:
    """
    Gets the latest version tag from changelog files.
    Returns the highest version found in changelog files.
    """
    changelog_files = get_changelog_files(module_path)
    
    if not changelog_files:
        return None
    
    # Find the highest version
    latest_version = changelog_files[0][0]
    for version, _ in changelog_files[1:]:
        if compare_versions(version, latest_version) > 0:
            latest_version = version
    
    return latest_version


def get_newer_changelogs(module_path: str, current_version: str) -> List[Tuple[str, str]]:
    """
    Gets changelog files newer than the specified version.
    Returns list of tuples (version, changelog_content).
    """
    changelog_files = get_changelog_files(module_path)
    newer_changelogs = []
    
    for version, file_path in changelog_files:
        if compare_versions(version, current_version) > 0:
            content = read_changelog(file_path)
            newer_changelogs.append((version, content))
    
    # Sort by version
    newer_changelogs.sort(key=lambda x: parse_version(x[0]))
    
    return newer_changelogs


def main():
    parser = argparse.ArgumentParser(
        description='Gets changelog of versions newer than the specified module version on the channel'
    )
    parser.add_argument(
        'channel',
        nargs='?',
        help='Channel name (Alpha, Beta, Early Access, Stable, Rock Solid)'
    )
    parser.add_argument(
        'module_name',
        nargs='?',
        help='Module name'
    )
    parser.add_argument(
        '--module-path',
        default='.',
        help='Path to module (default: current directory)'
    )
    parser.add_argument(
        '--send',
        default='true',
        help='send message to channel'
    )
    
    args = parser.parse_args()
    
    latest_tag = get_latest_tag_from_changelogs(args.module_path)
    if latest_tag:
        print(latest_tag)
    else:
        print("No changelog files found", file=sys.stderr)
        sys.exit(1)
    
    # Validate required arguments for normal operation
    if not args.channel or not args.module_name:
        parser.error("channel and module_name are required")
    
    repo_urls = [
        'https://github.com/deckhouse/sds-node-configurator',
        'https://github.com/deckhouse/sds-replicated-volume',
        'https://github.com/deckhouse/sds-local-volume',
        'https://github.com/deckhouse/csi-nfs',
        'https://github.com/deckhouse/csi-ceph',
        'https://github.com/deckhouse/snapshot-controller',
        'https://fox.flant.com/deckhouse/storage/csi-yadro-tatlin-unified',
        'https://fox.flant.com/deckhouse/storage/csi-netapp',
        'https://fox.flant.com/deckhouse/storage/csi-hpe',
        'https://fox.flant.com/deckhouse/storage/csi-huawei',
        'https://fox.flant.com/deckhouse/storage/csi-s3',
        'https://fox.flant.com/deckhouse/storage/csi-scsi-generic',
        'https://fox.flant.com/deckhouse/storage/storage-volume-data-manager'
    ]

    # Normalize channel name for display
    normalized_channel = normalize_channel(args.channel)
    
    message_text = None
    for repo_url in repo_urls:
        if args.module_name in repo_url:
            if "github.com" in repo_url:
                message_text = f"**Модуль** **[{args.module_name}](https://github.com/deckhouse/{args.module_name})** Канал обновлений {normalized_channel}. Смена версии на {latest_tag} (*[релиз](https://github.com/deckhouse/{args.module_name}/releases/tag/{latest_tag})*)"
            elif "fox.flant.com" in repo_url:
                message_text = f"**Модуль** **[{args.module_name}](https://fox.flant.com/deckhouse/storage/{args.module_name})** Канал обновлений {normalized_channel}. Смена версии на {latest_tag} (*[релиз](https://fox.flant.com/deckhouse/storage/{args.module_name}/-/releases/{latest_tag})*)"
            break

    if not message_text:
        print(f"Module '{args.module_name}' not found in repo_urls", file=sys.stderr)
        sys.exit(1)

    # Get module version from channel
    current_version = get_module_version_from_channel(args.module_name, args.channel)
    
    if not current_version:
        print(f"Module '{args.module_name}' not found on channel '{normalized_channel}'", file=sys.stderr)
        sys.exit(1)
    
    print(f"Module '{args.module_name}' version on channel '{normalized_channel}': {current_version}")
    print()
    
    # Get changelog files newer than current version
    newer_changelogs = get_newer_changelogs(args.module_path, current_version)
    
    if not newer_changelogs:
        print("No versions newer than specified.")
        return
    
    print(f"Found {len(newer_changelogs)} versions newer than {current_version}:")
    print()
    
    for version, changelog_content in newer_changelogs:
        message_text += f"\n\n**{version}**"
        message_text += f"\n\n  - {'\n  - '.join(changelog_content)}"
        

    if args.send == 'true': 
        result = send_post_request(os.getenv('HOOK_URL'), os.getenv('LOOP_STORAGE_RELEASE_CHANNEL'), message_text)
    else:
        print(message_text)


if __name__ == "__main__":
    main()
