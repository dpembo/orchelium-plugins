# Scripts

This directory contains utility scripts for maintaining the orchelium-plugins repository.

## generate-registry.py

Generates `registry.json` from plugin metadata found in each plugin's `plugin.yaml` file.

### Usage

```bash
python3 scripts/generate-registry.py
```

This script:
- Scans all plugin directories
- Extracts metadata from `plugin.yaml` (name, version, label, description)
- Generates an updated `registry.json` file
- Updates the `updated` timestamp to the current date

### Automatic Execution

The registry is automatically regenerated on every push to `main` when any `plugin.yaml` file changes. See `.github/workflows/update-registry.yml` for details.
