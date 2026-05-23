"""YAML parsing utilities."""

import yaml
from pathlib import Path


def load_schema_file(path: Path) -> dict:
    """Load a schema from a YAML file."""
    return yaml.safe_load(path.read_text()) or {}
