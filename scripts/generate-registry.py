#!/usr/bin/env python3
"""
Generate registry.json from plugin.yaml files.
This version is strict, stable, and fully YAML‑aware.
"""

import json
import sys
from datetime import datetime
from pathlib import Path
import yaml


ROOT = Path(__file__).parent.parent
REGISTRY_FILE = ROOT / "registry.json"
REPO_URL = "https://github.com/dpembo/orchelium-plugins"


def load_plugin_yaml(path: Path):
    """Load plugin.yaml and return parsed dict."""
    with open(path, "r", encoding="utf-8") as f:
        data = yaml.safe_load(f)

    if not isinstance(data, dict):
        raise ValueError(f"{path} does not contain a valid YAML object")

    return data


def validate_plugin(name: str, data: dict, folder: str):
    """Validate required fields and return normalized metadata."""
    required = ["name", "version", "label", "description", "category"]

    for field in required:
        if field not in data or not data[field]:
            raise ValueError(f"Plugin '{folder}' missing required field: {field}")

    # Normalize tags
    tags = data.get("tags", [])
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",")]
    elif not isinstance(tags, list):
        tags = []

    # Normalize source
    source = data.get("source", "community")
    official = source == "official"

    # Optional fields
    maintainer = data.get("maintainer")
    repo_url = data.get("repository_url", REPO_URL)
    min_version = data.get("minOrcheliumVersion", "1.0.0")

    return {
        "name": data["name"],
        "label": data["label"],
        "description": data["description"],
        "version": data["version"],
        "category": data["category"],
        "tags": tags,
        "source": source,
        "official": official,
        "path": folder,
        "minOrcheliumVersion": min_version,
        "maintainer": maintainer,
        "repository_url": repo_url,
    }


def main():
    plugins = []

    # Scan only directories containing plugin.yaml
    for folder in sorted(ROOT.iterdir()):
        if not folder.is_dir():
            continue
        if folder.name.startswith("."):
            continue
        if folder.name in ("scripts", ".github", "__pycache__"):
            continue

        plugin_yaml = folder / "plugin.yaml"
        if not plugin_yaml.exists():
            continue

        try:
            data = load_plugin_yaml(plugin_yaml)
            plugin = validate_plugin(data.get("name"), data, folder.name)
            plugins.append(plugin)
        except Exception as e:
            print(f"✗ Error in {folder.name}: {e}")
            sys.exit(1)

    # Sort plugins alphabetically
    plugins.sort(key=lambda p: p["name"])

    registry = {
        "registryVersion": "1",
        "updated": datetime.now().strftime("%Y-%m-%d"),
        "source": REPO_URL,
        "plugins": plugins,
    }

    with open(REGISTRY_FILE, "w", encoding="utf-8") as f:
        json.dump(registry, f, indent=2)

    print(f"✓ registry.json generated with {len(plugins)} plugins")
    return 0


if __name__ == "__main__":
    sys.exit(main())
