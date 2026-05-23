"""Data client for schema-driven entity management."""

import os
import re
import shutil
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import TYPE_CHECKING, Optional

from toolbox.shared.frontmatter import parse_frontmatter, serialize_frontmatter
from toolbox.shared.yaml import load_schema_file

if TYPE_CHECKING:
    from typing import Self


# =============================================================================
# Entity class
# =============================================================================


@dataclass
class Entity:
    """Represents an entity in a collection.

    Entities can be stored as:
    - Flat: data/<collection>/<slug>.md
    - Subdirectory: data/<collection>/<slug>/<index_file>.md

    Attachments are only supported for subdirectory entities.
    Flat entities are automatically promoted when adding attachments.
    """

    collection: str
    slug: str
    frontmatter: dict
    content: str
    path: Path  # Path to the main .md file
    _client: "DataClient" = field(repr=False)

    @property
    def dir(self) -> Optional[Path]:
        """Entity directory, or None if flat."""
        schema = self._client.get_schema(self.collection)
        index_filename = schema.get("filename", "index.md") if schema else "index.md"

        # Check if entity is in subdirectory format
        if self.path.parent.name == self.slug and self.path.name == index_filename:
            return self.path.parent
        # Also check for non-standard index filename in subdir
        if self.path.parent.name == self.slug:
            return self.path.parent
        return None

    @property
    def is_subdir(self) -> bool:
        """True if entity uses subdirectory structure."""
        return self.dir is not None

    def list_attachments(self) -> list[str]:
        """List attachment filenames. Returns empty list for flat entities."""
        if not self.is_subdir:
            return []

        schema = self._client.get_schema(self.collection)
        index_filename = schema.get("filename", "index.md") if schema else "index.md"

        attachments = []
        for item in sorted(self.dir.iterdir()):
            if item.is_file() and item.name != index_filename:
                attachments.append(item.name)
        return attachments

    def get_attachment(self, name: str) -> Optional[dict]:
        """Get attachment info. Returns None if not found or entity is flat."""
        if not self.is_subdir:
            return None

        file_path = self.dir / name
        if not file_path.is_file():
            return None

        result = {"name": name, "path": str(file_path)}
        if _is_text_file(file_path):
            result["content"] = file_path.read_text()
        else:
            result["size"] = file_path.stat().st_size
            result["binary"] = True
        return result

    def add_attachment(self, source: Path, name: str = None) -> dict:
        """Add attachment, auto-promoting to subdirectory if needed."""
        source = Path(source)
        if not source.is_file():
            raise FileNotFoundError(f"Source file not found: {source}")

        # Auto-promote if flat
        if not self.is_subdir:
            self.promote()

        schema = self._client.get_schema(self.collection)
        index_filename = schema.get("filename", "index.md") if schema else "index.md"

        attachment_name = name or source.name
        if attachment_name == index_filename:
            raise ValueError(
                f"Cannot overwrite index file '{index_filename}' as attachment"
            )

        dest_path = self.dir / attachment_name
        shutil.copy2(source, dest_path)

        return {"name": attachment_name, "path": str(dest_path)}

    def delete_attachment(self, name: str) -> bool:
        """Delete attachment. Returns False if not found or entity is flat."""
        if not self.is_subdir:
            return False

        schema = self._client.get_schema(self.collection)
        index_filename = schema.get("filename", "index.md") if schema else "index.md"

        if name == index_filename:
            raise ValueError(f"Cannot delete index file '{index_filename}'")

        file_path = self.dir / name
        if not file_path.is_file():
            return False

        file_path.unlink()
        return True

    def promote(self) -> "Self":
        """Convert flat entity to subdirectory structure.

        notes/idea.md → notes/idea/index.md
        """
        if self.is_subdir:
            return self  # Already subdirectory

        schema = self._client.get_schema(self.collection)
        index_filename = schema.get("filename", "index.md") if schema else "index.md"

        # Create directory and move file
        new_dir = self.path.parent / self.slug
        new_dir.mkdir(exist_ok=True)
        new_path = new_dir / index_filename

        self.path.rename(new_path)
        self.path = new_path

        return self

    def flatten(self, force: bool = False) -> "Self":
        """Convert subdirectory entity to flat structure.

        notes/idea/index.md → notes/idea.md

        Raises ValueError if attachments exist unless force=True.
        """
        if not self.is_subdir:
            return self  # Already flat

        attachments = self.list_attachments()
        if attachments and not force:
            raise ValueError(
                f"Cannot flatten: entity has {len(attachments)} attachments. "
                f"Use force=True to delete them."
            )

        # Delete attachments if forcing
        for att in attachments:
            self.delete_attachment(att)

        # Move file and remove directory
        entity_dir = self.dir
        new_path = entity_dir.parent / f"{self.slug}.md"

        self.path.rename(new_path)
        entity_dir.rmdir()
        self.path = new_path

        return self

    def to_dict(self) -> dict:
        """Convert to dict representation (for JSON serialization)."""
        return {
            "slug": self.slug,
            "frontmatter": self.frontmatter,
            "content": self.content,
            "path": str(self.path),
            "is_subdir": self.is_subdir,
            "attachments": self.list_attachments() if self.is_subdir else [],
        }


def _is_text_file(path: Path) -> bool:
    """Detect if file is text (for content reading)."""
    text_extensions = {
        ".md",
        ".txt",
        ".html",
        ".css",
        ".js",
        ".json",
        ".yaml",
        ".yml",
        ".xml",
        ".csv",
        ".py",
        ".sh",
        ".nix",
        ".toml",
    }
    return path.suffix.lower() in text_extensions


# =============================================================================
# Helper functions
# =============================================================================


def find_data_dir() -> Path:
    """Find the data directory.

    Prefers cwd for writing (kit_dir may be read-only Nix store).
    """
    # Prefer current working directory for writing
    cwd = Path.cwd()
    cwd_data = cwd / "data"
    if cwd_data.is_dir():
        return cwd_data

    # Check KIT_SYSTEM_DIR env var (for installed package)
    if env_dir := os.environ.get("KIT_SYSTEM_DIR"):
        return Path(env_dir) / "data"

    # Fallback to script directory
    script_dir = Path(__file__).parent.parent.parent
    return script_dir / "data"


def to_kebab(name: str) -> str:
    """Convert a name to kebab-case."""
    # Handle already kebab-cased names
    if "-" in name and " " not in name:
        return name.lower()
    # Convert spaces and underscores to hyphens, lowercase
    result = re.sub(r"[\s_]+", "-", name.lower())
    # Remove any non-alphanumeric characters except hyphens
    result = re.sub(r"[^a-z0-9-]", "", result)
    # Remove multiple consecutive hyphens
    result = re.sub(r"-+", "-", result)
    return result.strip("-")


class DataClient:
    """Client for schema-driven entity management."""

    def __init__(self):
        self.data_dir = find_data_dir()
        self._schemas: dict[str, dict] = {}
        self._load_schemas()

    def _load_schemas(self) -> None:
        """Load schemas from _schema.yaml in each collection directory."""
        for item in self.data_dir.iterdir():
            if item.is_dir() and not item.name.startswith("_"):
                schema_file = item / "_schema.yaml"
                if schema_file.exists():
                    schema = load_schema_file(schema_file)
                    # Collection name is the directory name
                    collection_name = item.name
                    schema["name"] = collection_name
                    schema["directory"] = collection_name
                    self._schemas[collection_name] = schema

    def list_collections(self) -> list[str]:
        """List all available collections (directories with _schema.yaml)."""
        return sorted(self._schemas.keys())

    def get_schema(self, collection: str) -> Optional[dict]:
        """Get a schema by collection name."""
        return self._schemas.get(collection)

    def get_list_defaults(self, collection: str) -> dict:
        """Get default list configuration from schema."""
        schema = self._schemas.get(collection, {})
        list_config = schema.get("list", {})
        return {
            "fields": list_config.get("fields"),
            "sort_by": list_config.get("sort", {}).get("field"),
            "sort_desc": list_config.get("sort", {}).get("desc", False),
        }

    def get_enum_sort_map(self, collection: str, field: str) -> Optional[dict]:
        """Get sort map for enum field based on values order."""
        schema = self._schemas.get(collection, {})
        field_config = schema.get("fields", {}).get(field, {})
        if field_config.get("type") == "enum":
            values = field_config.get("values", [])
            return {v: str(i) for i, v in enumerate(values)}
        return None

    def _get_collection_dir(self, collection: str) -> Path:
        """Get the directory for a collection."""
        if collection not in self._schemas:
            raise ValueError(f"Unknown collection: {collection}")
        return self.data_dir / collection

    def _generate_slug(self, collection: str, data: dict) -> str:
        """Generate a slug/filename for an entity."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        slug_config = schema.get("slug", {})
        field = slug_config.get("field", "name")
        format_type = slug_config.get("format", "kebab")
        default = slug_config.get("default")

        # Get the value for the slug field
        value = data.get(field)

        # Apply default if no value and default is specified
        if not value and default:
            if default == "today":
                value = date.today().isoformat()
            else:
                value = default

        if not value:
            raise ValueError(f"Cannot generate slug: field '{field}' is required")

        # Apply format
        if format_type == "kebab":
            return to_kebab(value)
        elif format_type == "literal":
            return str(value)
        else:
            return to_kebab(value)

    def _validate_frontmatter(self, collection: str, frontmatter: dict) -> list[str]:
        """Validate frontmatter against a collection's schema. Returns list of errors."""
        schema = self._schemas.get(collection)
        if not schema:
            return [f"Unknown collection: {collection}"]

        errors = []

        # Check reserved field names
        if "content" in frontmatter:
            errors.append("Field name 'content' is reserved for the markdown body")

        # Check required fields
        for req_field in schema.get("required", []):
            if req_field not in frontmatter:
                errors.append(f"Missing required field: {req_field}")

        # Validate field types and enum values
        fields = schema.get("fields", {})
        for field_name, field_config in fields.items():
            if field_name not in frontmatter:
                continue

            value = frontmatter[field_name]
            field_type = (
                field_config.get("type") if isinstance(field_config, dict) else None
            )

            if field_type == "enum":
                valid_values = field_config.get("values", [])
                if valid_values and value not in valid_values:
                    errors.append(
                        f"Invalid {field_name} '{value}', must be one of: {', '.join(valid_values)}"
                    )
            elif field_type == "date":
                # Basic date format validation
                if not re.match(r"^\d{4}-\d{2}-\d{2}$", str(value)):
                    errors.append(
                        f"Invalid date format for {field_name}: '{value}' (expected YYYY-MM-DD)"
                    )

        return errors

    def _resolve_slug(self, collection: str, slug: str = None) -> str:
        """Resolve slug, applying default if not provided."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        if slug:
            return slug

        slug_config = schema.get("slug", {})
        default = slug_config.get("default")
        if default == "today":
            return date.today().isoformat()
        elif default:
            return default
        else:
            raise ValueError("Slug is required (no default configured)")

    def list_entities(
        self, collection: str, include_content: bool = False
    ) -> list[dict]:
        """List all entities in a collection."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        collection_dir = self._get_collection_dir(collection)
        if not collection_dir.is_dir():
            return []

        # Get schema-defined filename for nested entities
        schema_filename = self._get_entity_filename(collection)

        # Use recursive glob if schema specifies it
        recursive = schema.get("recursive", "false") == "true"

        entities = []

        # Handle nested structure (e.g., skills/morning/SKILL.md or notes/foo/index.md)
        # Check if schema explicitly declares filename (indicates nested structure)
        if "filename" in schema:
            for subdir in sorted(collection_dir.iterdir()):
                if subdir.is_dir() and not subdir.name.startswith("_"):
                    file_path = subdir / schema_filename
                    if file_path.exists():
                        content = file_path.read_text()
                        frontmatter, body = parse_frontmatter(content)
                        slug = subdir.name

                        entity = {"slug": slug, "frontmatter": frontmatter}
                        if include_content:
                            entity["content"] = body.strip()
                        entities.append(entity)
        else:
            # Standard glob for flat files
            glob_pattern = "**/*.md" if recursive else "*.md"

            for file_path in sorted(collection_dir.glob(glob_pattern)):
                # Skip schema file
                if file_path.name == "_schema.yaml":
                    continue

                content = file_path.read_text()
                frontmatter, body = parse_frontmatter(content)

                # For recursive schemas, include relative path in slug
                if recursive:
                    rel_path = file_path.relative_to(collection_dir)
                    slug = str(rel_path.with_suffix(""))
                else:
                    slug = file_path.stem

                entity = {"slug": slug, "frontmatter": frontmatter}
                if include_content:
                    entity["content"] = body.strip()

                entities.append(entity)

        return entities

    def _get_entity_filename(self, collection: str) -> str:
        """Get the default filename for nested entities from schema."""
        schema = self._schemas.get(collection, {})
        return schema.get("filename", "index.md")

    def _get_entity_path(self, collection: str, slug: str) -> Path:
        """Support both entry.md and entry/<filename> formats.

        Uses schema-defined 'filename' field (defaults to index.md).
        """
        collection_dir = self.data_dir / collection
        schema_filename = self._get_entity_filename(collection)

        # Try flat file first
        flat_path = collection_dir / f"{slug}.md"
        if flat_path.exists():
            return flat_path

        # Try nested format with schema-defined filename
        nested_path = collection_dir / slug / schema_filename
        if nested_path.exists():
            return nested_path

        # For collections with custom filename, default to nested structure
        if schema_filename != "index.md":
            return nested_path

        return flat_path  # Default to flat for new entities

    def get_entity(self, collection: str, slug: str = None) -> Optional[dict]:
        """Get a single entity by collection and slug."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        slug = self._resolve_slug(collection, slug)
        collection_dir = self._get_collection_dir(collection)
        file_path = self._get_entity_path(collection, slug)

        # For recursive schemas, search subdirectories if direct path not found
        if not file_path.exists():
            recursive = schema.get("recursive", "false") == "true"
            if recursive:
                for found_path in collection_dir.glob(f"**/{slug}.md"):
                    file_path = found_path
                    break
                else:
                    return None
            else:
                return None

        content = file_path.read_text()
        frontmatter, body = parse_frontmatter(content)

        return {"slug": slug, "frontmatter": frontmatter, "content": body.strip()}

    def get_entity_obj(self, collection: str, slug: str = None) -> Optional[Entity]:
        """Get a single entity as an Entity object."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        slug = self._resolve_slug(collection, slug)
        file_path = self._get_entity_path(collection, slug)

        if not file_path.exists():
            return None

        content = file_path.read_text()
        frontmatter, body = parse_frontmatter(content)

        return Entity(
            collection=collection,
            slug=slug,
            frontmatter=frontmatter,
            content=body.strip(),
            path=file_path,
            _client=self,
        )

    def create_entity(
        self,
        collection: str,
        frontmatter: dict,
        content: str = "",
        slug: str = None,
    ) -> dict:
        """Create a new entity in a collection."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        # Generate slug if not provided
        if not slug:
            slug = self._generate_slug(collection, frontmatter)

        # Validate frontmatter
        errors = self._validate_frontmatter(collection, frontmatter)
        if errors:
            raise ValueError(f"Validation failed: {'; '.join(errors)}")

        # Check if entity exists
        collection_dir = self._get_collection_dir(collection)
        collection_dir.mkdir(parents=True, exist_ok=True)

        # Determine file path based on schema filename
        schema_filename = self._get_entity_filename(collection)
        if schema_filename != "index.md":
            # Nested structure: skills/morning/SKILL.md
            entity_dir = collection_dir / slug
            entity_dir.mkdir(parents=True, exist_ok=True)
            file_path = entity_dir / schema_filename
        else:
            # Flat structure: prompts/morning.md
            file_path = collection_dir / f"{slug}.md"

        if file_path.exists():
            raise ValueError(f"Entity already exists: {file_path}. Use update instead.")

        # Write the file
        file_content = f"---\n{serialize_frontmatter(frontmatter)}\n---\n\n{content}\n"
        file_path.write_text(file_content)

        return {"slug": slug, "frontmatter": frontmatter, "content": content}

    def update_entity(
        self,
        collection: str,
        slug: str = None,
        frontmatter: dict = None,
        content: str = None,
        append: bool = False,
    ) -> dict:
        """Update an existing entity."""
        schema = self._schemas.get(collection)
        if not schema:
            raise ValueError(f"Unknown collection: {collection}")

        slug = self._resolve_slug(collection, slug)
        file_path = self._get_entity_path(collection, slug)

        # If file doesn't exist and we're appending, create it
        if not file_path.exists():
            if append and content:
                new_frontmatter = frontmatter or {}
                if collection == "journal":
                    new_frontmatter.setdefault("date", slug)
                    new_frontmatter.setdefault("type", "daily")
                    new_frontmatter.setdefault("tags", [])
                return self.create_entity(collection, new_frontmatter, content, slug)
            raise ValueError(f"Entity not found: {file_path}")

        # Read existing
        existing_content = file_path.read_text()
        existing_fm, existing_body = parse_frontmatter(existing_content)

        # Merge frontmatter
        new_fm = {**existing_fm}
        if frontmatter:
            new_fm.update(frontmatter)

        # Update content
        new_body = existing_body.strip()
        if content is not None:
            if append:
                new_body = new_body + "\n\n---\n\n" + content
            else:
                new_body = content

        # Validate
        errors = self._validate_frontmatter(collection, new_fm)
        if errors:
            raise ValueError(f"Validation failed: {'; '.join(errors)}")

        # Write back
        file_content = (
            f"---\n{serialize_frontmatter(new_fm)}\n---\n\n{new_body.strip()}\n"
        )
        file_path.write_text(file_content)

        return {"slug": slug, "frontmatter": new_fm, "content": new_body.strip()}

    def delete_entity(self, collection: str, slug: str) -> bool:
        """Delete an entity from a collection."""
        file_path = self._get_entity_path(collection, slug)

        if not file_path.exists():
            return False

        file_path.unlink()
        return True

    def query_by_field(self, collection: str, field: str, value: any) -> Optional[dict]:
        """Find first entity where frontmatter[field] == value.

        Args:
            collection: The collection to search
            field: The frontmatter field to match
            value: The value to match (compared as string)

        Returns:
            The matching entity dict or None if not found
        """
        str_value = str(value)
        for entity in self.list_entities(collection):
            field_value = entity["frontmatter"].get(field)
            if field_value is not None and str(field_value) == str_value:
                return self.get_entity(collection, entity["slug"])
        return None

    def query_entities(
        self,
        collection: str,
        filters: dict = None,
        sort_by: str = None,
        sort_desc: bool = False,
        sort_map: dict = None,
    ) -> list[dict]:
        """Query entities with flexible filtering and sorting.

        Args:
            collection: The collection to search
            filters: Dict of field -> value or field -> {operator: value}
                Supported operators:
                - eq: exact match (default)
                - ne: not equal
                - gt, gte, lt, lte: comparison
                - in: value in list
                - contains: list field contains value
            sort_by: Field name to sort by
            sort_desc: Sort descending (default False)
            sort_map: Dict mapping field values to sort keys (unmapped values sort last)

        Returns:
            List of matching entity dicts with slug, frontmatter, and content

        Examples:
            # Exact match
            query_entities("clients", {"status": "active"})

            # Comparison
            query_entities("leads", {"stage": {"ne": "closed-lost"}})

            # List contains
            query_entities("contacts", {"accounts": {"contains": "supabase"}})

            # Sort with custom ordering
            query_entities("tasks", sort_by="priority",
                sort_map={"high": "0", "medium": "1", "low": "2"})
        """
        entities = self.list_entities(collection, include_content=True)
        filters = filters or {}

        def matches_filter(entity: dict) -> bool:
            fm = entity.get("frontmatter", {})
            for filter_field, condition in filters.items():
                field_value = fm.get(filter_field)

                # Handle operator dict
                if isinstance(condition, dict):
                    for op, expected in condition.items():
                        if op == "eq":
                            if field_value != expected:
                                return False
                        elif op == "ne":
                            if field_value == expected:
                                return False
                        elif op == "gt":
                            if field_value is None or field_value <= expected:
                                return False
                        elif op == "gte":
                            if field_value is None or field_value < expected:
                                return False
                        elif op == "lt":
                            if field_value is None or field_value >= expected:
                                return False
                        elif op == "lte":
                            if field_value is None or field_value > expected:
                                return False
                        elif op == "in":
                            if field_value not in expected:
                                return False
                        elif op == "contains":
                            # Check if list field contains the value
                            if not isinstance(field_value, list):
                                return False
                            if expected not in field_value:
                                return False
                else:
                    # Simple exact match
                    if field_value != condition:
                        return False
            return True

        results = [e for e in entities if matches_filter(e)]

        # Sort if requested
        if sort_by:
            if sort_map:
                max_key = chr(0x10FFFF)
                results.sort(
                    key=lambda e: sort_map.get(
                        str(e.get("frontmatter", {}).get(sort_by) or ""), max_key
                    ),
                    reverse=sort_desc,
                )
            else:
                results.sort(
                    key=lambda e: e.get("frontmatter", {}).get(sort_by) or "",
                    reverse=sort_desc,
                )

        return results

    # =========================================================================
    # Attachment methods (delegate to Entity)
    # =========================================================================

    def list_attachments(self, collection: str, slug: str) -> list[str]:
        """List all attachments for an entity."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        return entity.list_attachments()

    def get_attachment(self, collection: str, slug: str, name: str) -> Optional[dict]:
        """Get attachment info."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        return entity.get_attachment(name)

    def add_attachment(
        self, collection: str, slug: str, source: Path, name: str = None
    ) -> dict:
        """Add attachment, auto-promoting flat entities to subdirectory."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        return entity.add_attachment(source, name)

    def delete_attachment(self, collection: str, slug: str, name: str) -> bool:
        """Delete an attachment."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        return entity.delete_attachment(name)

    # =========================================================================
    # Structure conversion methods
    # =========================================================================

    def promote_entity(self, collection: str, slug: str) -> dict:
        """Convert flat entity to subdirectory structure."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        entity.promote()
        return entity.to_dict()

    def flatten_entity(self, collection: str, slug: str, force: bool = False) -> dict:
        """Convert subdirectory entity to flat structure."""
        entity = self.get_entity_obj(collection, slug)
        if not entity:
            raise ValueError(f"Entity not found: {collection}/{slug}")
        entity.flatten(force=force)
        return entity.to_dict()
