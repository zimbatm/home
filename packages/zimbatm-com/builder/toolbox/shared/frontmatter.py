"""Frontmatter parsing and serialization utilities."""

import re

import yaml


class _SafeLoader(yaml.SafeLoader):
    """SafeLoader that disables YAML 1.1 sexagesimal (e.g. 10:30 -> 630)."""

    pass


# PyYAML's SafeLoader uses YAML 1.1 which interprets "10:30" as sexagesimal (630).
# Override the implicit resolvers to remove the sexagesimal patterns for int and float.
# We rebuild the resolver map for our subclass, stripping the colon-based patterns.
_SafeLoader.yaml_implicit_resolvers = {}
for key, resolvers in yaml.SafeLoader.yaml_implicit_resolvers.items():
    _SafeLoader.yaml_implicit_resolvers[key] = [
        (tag, regexp)
        for tag, regexp in resolvers
        if not (
            tag in ("tag:yaml.org,2002:int", "tag:yaml.org,2002:float")
            and ":" in regexp.pattern
        )
    ]


def parse_frontmatter(content: str) -> tuple[dict, str]:
    """Parse YAML frontmatter from markdown content.

    Returns (frontmatter_dict, content_without_frontmatter)
    """
    if not content.startswith("---\n"):
        return {}, content

    # Find the closing ---
    end_match = re.search(r"\n---\n", content[4:])
    if not end_match:
        return {}, content

    frontmatter_text = content[4 : 4 + end_match.start()]
    body = content[4 + end_match.end() :]

    try:
        frontmatter = yaml.load(frontmatter_text, Loader=_SafeLoader)
    except yaml.YAMLError:
        return {}, content
    if not isinstance(frontmatter, dict):
        return {}, content

    # Coerce all non-list, non-bool values to strings for consistency
    for key, value in frontmatter.items():
        if isinstance(value, bool):
            pass  # keep bools as-is
        elif isinstance(value, list):
            frontmatter[key] = [str(item) for item in value]
        elif not isinstance(value, str):
            frontmatter[key] = str(value)

    return frontmatter, body


def serialize_frontmatter(frontmatter: dict) -> str:
    """Serialize frontmatter dict to YAML string."""
    if not frontmatter:
        return ""
    return yaml.dump(
        frontmatter,
        default_flow_style=False,
        allow_unicode=True,
        sort_keys=False,
    ).rstrip()
