# Contributing to orchelium-plugins

Thank you for contributing! This document covers how to add a new plugin or improve an existing one.

## Adding a New Plugin

### 1. Create the plugin directory

Plugin names must be lowercase and may only contain letters, digits, and hyphens (`[a-z0-9-]`).

```
mkdir my-plugin
```

### 2. Write `plugin.yaml`

This is the only required file. Minimum viable example:

```yaml
name: my-plugin
version: 1.0.0
label: My Plugin
description: |
  One or two sentences explaining what this plugin does.

inputs:
  - name: source
    label: Source Path
    type: string
    required: true

command: run.sh
```

Full field reference is in the [Orchelium developer guide](https://github.com/dpembo/orchelium/blob/main/docs/Developers/developer-guide.md).

### 3. Write `run.sh`

The script is executed on the Orchelium agent. Input values are passed as environment variables matching the input `name` fields (uppercased).

```bash
#!/usr/bin/env bash
set -euo pipefail

echo "Source: $SOURCE"
```

Make sure it is executable:

```bash
chmod +x run.sh
```

### 4. Add an icon (optional)

Provide an `icon.svg` — a square SVG, ideally 24 × 24 or 48 × 48 px. Use a single-colour path so it renders correctly in both light and dark themes.

### 5. Write `docs.md` (optional but recommended)

Markdown documentation shown in the Plugin Manager detail panel. Include:

- Prerequisites (what must be installed on the agent)
- Example configurations
- Common error messages and how to resolve them

### 6. Update `registry.json`

Add an entry for your plugin to `registry.json` at the root of this repository:

```json
{
  "name": "my-plugin",
  "label": "My Plugin",
  "description": "One sentence description.",
  "version": "1.0.0",
  "category": "file-sync",
  "tags": ["tag1", "tag2"],
  "official": false,
  "path": "my-plugin",
  "minOrcheliumVersion": "1.0.0"
}
```

Valid categories: `backup`, `databases`, `file-sync`, `storage`, `containers`.

### 7. Open a Pull Request

- One plugin per PR
- PR title: `feat: add <plugin-name> plugin`
- Describe what the plugin does and any prerequisites in the PR description

## Updating an Existing Plugin

- Bump the `version` field in both `plugin.yaml` and `registry.json`
- Use semver: `MAJOR.MINOR.PATCH`
  - `PATCH` — bug fix, no behaviour change
  - `MINOR` — new optional input or operation
  - `MAJOR` — breaking change to existing inputs or behaviour
- PR title: `fix: <plugin-name> ...` or `feat: <plugin-name> ...`

## Security

Plugins execute shell scripts on agents — they are powerful by design. All submissions are reviewed before merge. Do not include:

- Hardcoded credentials or tokens
- `curl | bash` style remote code execution
- Unnecessary use of `sudo` or privilege escalation

## Questions

Open an issue in this repository or the main [orchelium](https://github.com/dpembo/orchelium) repository.
