#!/usr/bin/env python3
"""
Generate registry.json from plugin.yaml files in the plugins directory.
"""

import json
import os
import sys
from datetime import datetime
from pathlib import Path

def get_plugin_metadata(plugin_dir):
    """Extract plugin metadata from plugin.yaml file."""
    plugin_yaml = plugin_dir / "plugin.yaml"
    
    if not plugin_yaml.exists():
        return None
    
    try:
        import yaml
        with open(plugin_yaml, 'r') as f:
            data = yaml.safe_load(f)
        
        if not isinstance(data, dict):
            return None
        
        # Handle tags - could be a list or string
        tags = data.get('tags', [])
        if isinstance(tags, str):
            tags = [t.strip() for t in tags.split(',')]
        
        metadata = {
            'name': data.get('name', ''),
            'version': data.get('version', '1.0.0'),
            'label': data.get('label', ''),
            'description': data.get('description', ''),
            'category': data.get('category', ''),
            'tags': tags if isinstance(tags, list) else []
        }
        
        return metadata if metadata['name'] else None
    except ImportError:
        # Fallback: manual YAML parsing for top-level fields only
        metadata = {
            'tags': []
        }
        
        with open(plugin_yaml, 'r') as f:
            content = f.read()
        
        # Parse top-level fields
        for line in content.split('\n'):
            stripped = line.strip()
            current_indent = len(line) - len(line.lstrip())
            
            # Only process top-level fields (no indentation)
            if current_indent == 0 and ':' in stripped and not stripped.startswith('#'):
                key, value = stripped.split(':', 1)
                key = key.strip()
                value = value.strip()
                
                if key == 'name':
                    metadata['name'] = value.strip('"\'')
                elif key == 'version':
                    metadata['version'] = value.strip('"\'')
                elif key == 'label':
                    metadata['label'] = value.strip('"\'')
                elif key == 'category':
                    metadata['category'] = value.strip('"\'')
                elif key == 'tags':
                    # Handle tags: [backup, dedup, encryption, ssh]
                    if value.startswith('[') and value.endswith(']'):
                        tags_str = value[1:-1]  # Remove brackets
                        metadata['tags'] = [t.strip().strip('"\'') for t in tags_str.split(',')]
                elif key == 'description':
                    # Description can be multiline (| or >)
                    if value in ['|', '>']:
                        # Multi-line YAML - collect following indented lines
                        desc_lines = []
                        lines = content.split('\n')
                        idx = None
                        for i, l in enumerate(lines):
                            if l.strip().startswith('description:'):
                                idx = i
                                break
                        if idx is not None:
                            for i in range(idx + 1, len(lines)):
                                if lines[i] and lines[i][0] not in ' \t':
                                    break  # End of description block
                                if lines[i].strip():
                                    desc_lines.append(lines[i].strip())
                            metadata['description'] = ' '.join(desc_lines)
                    else:
                        metadata['description'] = value.strip('"\'')
        
        # Ensure required fields exist
        if 'name' not in metadata or not metadata.get('name'):
            return None
        
        for key in ['version', 'label', 'description', 'category']:
            metadata.setdefault(key, '')
        metadata.setdefault('tags', [])
        
        return metadata

def main():
    # Get the root directory (where registry.json is)
    root_dir = Path(__file__).parent.parent
    
    plugins = []
    
    # Scan all directories for plugins
    for item in sorted(root_dir.iterdir()):
        if not item.is_dir():
            continue
        
        if item.name in ['.git', 'scripts', '__pycache__', '.github']:
            continue
        
        plugin_metadata = get_plugin_metadata(item)
        if plugin_metadata:
            # Add standard fields
            plugin = {
                "name": plugin_metadata.get('name'),
                "label": plugin_metadata.get('label', plugin_metadata.get('name', '')),
                "description": plugin_metadata.get('description', ''),
                "version": plugin_metadata.get('version', '1.0.0'),
                "category": plugin_metadata.get('category', ''),
                "tags": plugin_metadata.get('tags', []),
                "official": True,
                "path": item.name,
                "minOrcheliumVersion": "1.0.0"
            }
            plugins.append(plugin)
    
    # Generate registry
    registry = {
        "registryVersion": "1",
        "updated": datetime.now().strftime("%Y-%m-%d"),
        "source": "https://github.com/dpembo/orchelium-plugins",
        "plugins": plugins
    }
    
    # Write registry.json
    registry_file = root_dir / "registry.json"
    with open(registry_file, 'w') as f:
        json.dump(registry, f, indent=2)
    
    print(f"✓ Generated registry.json with {len(plugins)} plugins")
    return 0

if __name__ == "__main__":
    sys.exit(main())
