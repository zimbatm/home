"""View renderer - converts data collections to HTML."""

import mimetypes
import re
from pathlib import Path
from typing import Optional

import yaml

from toolbox.data.client import DataClient
from toolbox.shared.frontmatter import parse_frontmatter


def parse_view_config(content: str) -> dict:
    """Parse view config from YAML frontmatter."""
    if not content.startswith("---\n"):
        return {}

    end_idx = content.find("\n---\n", 4)
    if end_idx == -1:
        return {}

    yaml_text = content[4:end_idx]
    config = yaml.safe_load(yaml_text)
    if not isinstance(config, dict):
        return {}
    return config


class ViewRenderer:
    """Renders a view to HTML."""

    def __init__(self, view_name: str, data_dir: Path):
        """Initialize renderer.

        Args:
            view_name: Name of the view (e.g., 'zimbatm.com')
            data_dir: Path to data directory
        """
        self.view_name = view_name
        self.data_dir = data_dir
        self.view_dir = data_dir / "views" / view_name

        # Load view config
        config_path = self.view_dir / "config.md"
        if not config_path.exists():
            raise ValueError(f"View config not found: {config_path}")

        content = config_path.read_text()
        self.config = parse_view_config(content)

        # Load base template
        base_path = self.view_dir / "base.html"
        self.base_template = (
            base_path.read_text() if base_path.exists() else "{content}"
        )

        # Build route table
        self._build_routes()

        # Build aliases (URL redirects/copies)
        self.aliases = {}
        for alias in self.config.get("aliases", []):
            if isinstance(alias, dict):
                from_path = alias.get("from", "").rstrip("/")
                to_path = alias.get("to", "").rstrip("/")
                if from_path and to_path:
                    self.aliases[from_path] = to_path

        # Build feed paths
        self.feeds = {}
        for feed in self.config.get("feeds", []):
            if isinstance(feed, dict):
                path = feed.get("path", "/feed.xml")
                self.feeds[path] = feed

    def _build_routes(self):
        """Build routing table from config."""
        self.routes = {}

        # Add collection routes
        for coll in self.config.get("collections", []):
            if isinstance(coll, str):
                # Simple format: just collection name
                coll = {"name": coll, "path": f"/{coll}"}

            name = coll.get("name")
            path = coll.get("path", f"/{name}")
            template = coll.get("template", "default.html")
            list_template = coll.get("list_template", "list.html")

            # Get schema defaults for fallback
            client = DataClient()
            client.data_dir = self.data_dir
            client._schemas = {}
            client._load_schemas()
            schema_defaults = client.get_list_defaults(name)

            # Use view config, fall back to schema defaults
            sort_by = coll.get("sort_by") or schema_defaults.get("sort_by")
            sort_order = coll.get("sort_order")
            if not sort_order and sort_by:
                sort_order = "desc" if schema_defaults.get("sort_desc") else "asc"
            else:
                sort_order = sort_order or "asc"

            # Parse sort_values (may be inline [a, b, c] or already a list)
            sort_values = coll.get("sort_values", [])
            if isinstance(sort_values, str) and sort_values.startswith("["):
                # Parse inline list format: [Alpha, Beta, Stable]
                sort_values = [v.strip() for v in sort_values[1:-1].split(",")]

            # Auto-derive sort_values from enum if not specified
            if not sort_values and sort_by:
                enum_map = client.get_enum_sort_map(name, sort_by)
                if enum_map:
                    sort_values = list(enum_map.keys())

            # List route
            self.routes[path] = {
                "type": "list",
                "collection": name,
                "template": list_template,
                "sort_by": sort_by,
                "sort_order": sort_order,
                "sort_values": sort_values,
                "group_by": coll.get("group_by"),
                "group_sort_by": coll.get("group_sort_by"),
                "group_sort_order": coll.get("group_sort_order", "asc"),
            }

            # Item routes (will be matched dynamically)
            self.routes[f"{path}/*"] = {
                "type": "item",
                "collection": name,
                "template": template,
                "path_prefix": path,
            }

        # Add page routes
        for page in self.config.get("pages", []):
            if isinstance(page, str):
                page = {"source": page, "path": f"/{page}"}

            source = page.get("source")
            path = page.get("path", "/")
            template = page.get("template", "default.html")
            base_template = page.get("base_template")

            self.routes[path] = {
                "type": "page",
                "source": source,
                "template": template,
                "base_template": base_template,
            }

    def render_path(self, path: str) -> tuple[Optional[bytes], str]:
        """Render a path to HTML or serve static file.

        Args:
            path: URL path (e.g., '/notes/nix-flakes')

        Returns:
            (content_bytes, content_type) or (None, '') if not found
        """
        # Normalize path
        path = path.rstrip("/") or "/"

        # Check for alias
        if path in self.aliases:
            path = self.aliases[path]

        # Check for static file in view dir
        if "." in path.split("/")[-1]:
            static_path = self.view_dir / path.lstrip("/")
            if static_path.exists() and static_path.is_file():
                content_type, _ = mimetypes.guess_type(str(static_path))
                return (
                    static_path.read_bytes(),
                    content_type or "application/octet-stream",
                )

        # Check for data dir files (images in collection folders)
        if path.startswith("/data/"):
            data_path = self.data_dir / path[6:]  # Remove "/data/" prefix
            if data_path.exists() and data_path.is_file():
                content_type, _ = mimetypes.guess_type(str(data_path))
                return (
                    data_path.read_bytes(),
                    content_type or "application/octet-stream",
                )

        # Check for feed
        if path in self.feeds:
            return self._render_feed(self.feeds[path])

        # Try exact route match
        if path in self.routes:
            return self._render_route(path, self.routes[path])

        # Try wildcard routes
        for route_path, route in self.routes.items():
            if route_path.endswith("/*"):
                prefix = route_path[:-2]
                if path.startswith(prefix + "/"):
                    slug = path[len(prefix) + 1 :]
                    return self._render_item(route, slug)

        return None, ""

    def _render_route(self, path: str, route: dict) -> tuple[Optional[bytes], str]:
        """Render a specific route."""
        route_type = route.get("type")

        if route_type == "list":
            return self._render_list(route)
        elif route_type == "page":
            return self._render_page(route)
        elif route_type == "item":
            # Extract slug from path
            slug = path[len(route.get("path_prefix", "")) + 1 :]
            return self._render_item(route, slug)

        return None, ""

    def _render_list(self, route: dict) -> tuple[bytes, str]:
        """Render a collection list page."""
        collection = route.get("collection")
        template_name = route.get("template", "list.html")
        sort_by = route.get("sort_by")
        sort_order = route.get("sort_order", "asc")
        sort_values = route.get("sort_values", [])
        group_by = route.get("group_by")
        group_sort_by = route.get("group_sort_by")
        group_sort_order = route.get("group_sort_order", "asc")

        # Get all items in collection
        client = DataClient()
        client.data_dir = self.data_dir
        client._schemas = {}
        client._load_schemas()

        entities = client.list_entities(collection)

        # Determine URL path for collection
        coll_path = f"/{collection}"
        for coll in self.config.get("collections", []):
            if isinstance(coll, dict) and coll.get("name") == collection:
                coll_path = coll.get("path", f"/{collection}")
                break

        # Sort entities
        if sort_by:
            if sort_values:
                # Sort by explicit value order
                def sort_key(e):
                    val = e.get("frontmatter", {}).get(sort_by, "")
                    try:
                        return sort_values.index(val)
                    except ValueError:
                        return len(sort_values)  # Unknown values at end
            else:
                # Sort by field value
                def sort_key(e):
                    return e.get("frontmatter", {}).get(sort_by, "")

            entities = sorted(entities, key=sort_key, reverse=(sort_order == "desc"))

        # Group entities if group_by is set
        if group_by:
            groups = {}
            for entity in entities:
                group_val = entity.get("frontmatter", {}).get(group_by, "Other")
                if group_val not in groups:
                    groups[group_val] = []
                groups[group_val].append(entity)

            # Sort within each group if group_sort_by is set
            if group_sort_by:
                for group_val in groups:
                    groups[group_val] = sorted(
                        groups[group_val],
                        key=lambda e: e.get("frontmatter", {}).get(group_sort_by, ""),
                        reverse=(group_sort_order == "desc"),
                    )

            # Order groups by sort_values if available
            if sort_values:
                ordered_groups = [
                    (v, groups.get(v, [])) for v in sort_values if v in groups
                ]
                # Add any groups not in sort_values
                for k, v in groups.items():
                    if k not in sort_values:
                        ordered_groups.append((k, v))
            else:
                ordered_groups = list(groups.items())

            # Render groups
            is_card_view = "project" in template_name or "gallery" in template_name
            groups_html = []
            for group_name, group_entities in ordered_groups:
                if not group_entities:
                    continue
                items_html = self._render_list_items(group_entities, coll_path, route)
                if is_card_view:
                    groups_html.append(
                        f'<div class="group">\n'
                        f'  <h2 class="group-header">{group_name}</h2>\n'
                        f'  <div class="cards">\n    {items_html}\n  </div>\n'
                        f"</div>"
                    )
                else:
                    groups_html.append(
                        f'<div class="group">\n'
                        f'  <h2 class="group-header">{group_name}</h2>\n'
                        f"  <ul>\n    {items_html}\n  </ul>\n"
                        f"</div>"
                    )

            # Load and fill template
            template = self._load_template(template_name)
            html = template.replace("{title}", collection.replace("-", " ").title())
            html = html.replace("{groups}", "\n".join(groups_html))
            html = html.replace("{items}", "")  # Clear items placeholder if present
        else:
            # Render flat list
            items_html = self._render_list_items(entities, coll_path, route)

            # Load and fill template
            template = self._load_template(template_name)
            html = template.replace("{title}", collection.replace("-", " ").title())
            html = html.replace("{items}", items_html)
            html = html.replace("{groups}", "")  # Clear groups placeholder if present

        # Wrap in base template
        title = collection.replace("-", " ").title()
        description = f"Browse {title.lower()} by zimbatm"
        html = self._wrap_base(html, title, description=description, url_path=coll_path)

        return html.encode("utf-8"), "text/html; charset=utf-8"

    def _render_list_items(self, entities: list, coll_path: str, route: dict) -> str:
        """Render a list of entities as HTML list items."""
        template_name = route.get("template", "list.html")
        is_project_list = "project" in template_name

        items_html = []
        for entity in entities:
            fm = entity.get("frontmatter", {})
            slug = entity.get("slug")
            title = fm.get("title", slug)
            date = fm.get("date", fm.get("created", ""))
            description = fm.get("description", "")
            homepage = fm.get("homepage", "").strip('"')

            if is_project_list:
                # Project card: title, description, homepage, dates, type
                project_type = fm.get("type", "software")
                created = fm.get("created", "")
                ended = fm.get("ended", "")

                if homepage:
                    domain = (
                        homepage.replace("https://", "")
                        .replace("http://", "")
                        .split("/")[0]
                    )
                    homepage_html = (
                        f'<a href="{homepage}" class="homepage">{domain}</a>'
                    )
                else:
                    homepage_html = ""

                # Format date range
                date_html = ""
                if created:
                    year_start = created[:4] if created else ""
                    year_end = ended[:4] if ended else ""
                    if year_end and year_end != year_start:
                        date_html = (
                            f'<span class="dates">{year_start}–{year_end}</span>'
                        )
                    elif year_start:
                        date_html = f'<span class="dates">{year_start}</span>'

                item_html = (
                    f'<a href="{coll_path}/{slug}" class="card card-{project_type}">\n'
                    f"      <h3>{title}</h3>\n"
                )
                if description:
                    item_html += f'      <p class="description">{description}</p>\n'
                if date_html or homepage_html:
                    item_html += '      <div class="card-meta">\n'
                    if date_html:
                        item_html += f"        {date_html}\n"
                    if homepage_html:
                        item_html += f'        <span class="homepage">{domain}</span>\n'
                    item_html += "      </div>\n"
                item_html += "    </a>"
            else:
                # Note-style item: title, date
                item_html = f'<li><a href="{coll_path}/{slug}">{title}</a>'
                if date:
                    item_html += f" <time>{date}</time>"
                item_html += "</li>"

            items_html.append(item_html)

        return "\n    ".join(items_html)

    def _render_item(self, route: dict, slug: str) -> tuple[Optional[bytes], str]:
        """Render a single collection item."""
        collection = route.get("collection")
        template_name = route.get("template", "default.html")

        # Get the entity
        client = DataClient()
        client.data_dir = self.data_dir
        client._schemas = {}
        client._load_schemas()

        entity = client.get_entity(collection, slug)
        if entity is None:
            return None, ""

        fm = entity.get("frontmatter", {})
        content = entity.get("content", "")

        # Check for page-specific template override
        if fm.get("template"):
            template_name = fm.get("template")

        # Convert markdown to HTML (basic)
        content_html = self._markdown_to_html(content, collection, slug)

        # Load and fill template
        template = self._load_template(template_name)
        html = self._fill_template(template, fm, content_html)

        # Get description from frontmatter or first line of content
        description = fm.get("description", "")
        if not description and content:
            # Use first non-empty line as description
            for line in content.split("\n"):
                line = line.strip()
                if line and not line.startswith("#"):
                    description = line
                    break

        # Get URL path
        url_path = route.get("path_prefix", f"/{collection}") + f"/{slug}"

        # Wrap in base template
        title = fm.get("title", slug)
        html = self._wrap_base(html, title, description=description, url_path=url_path)

        return html.encode("utf-8"), "text/html; charset=utf-8"

    def _render_page(self, route: dict) -> tuple[Optional[bytes], str]:
        """Render a standalone page."""
        source = route.get("source")
        template_name = route.get("template", "default.html")
        base_template_name = route.get("base_template")

        # Load the page source
        source_path = self.view_dir / source
        if not source_path.exists():
            return None, ""

        content = source_path.read_text()
        fm, body = parse_frontmatter(content)

        # Convert markdown to HTML
        content_html = self._markdown_to_html(body, None, None)

        # Load and fill template
        template = self._load_template(template_name)
        html = self._fill_template(template, fm, content_html)

        # Get description
        description = fm.get("description", "")
        if not description and body:
            for line in body.split("\n"):
                line = line.strip()
                if line and not line.startswith("#"):
                    description = line
                    break

        # Get URL path
        url_path = route.get("path", "/")

        # Wrap in base template (use custom if specified)
        title = fm.get("title", "")
        html = self._wrap_base(
            html, title, base_template_name, description=description, url_path=url_path
        )

        return html.encode("utf-8"), "text/html; charset=utf-8"

    def _load_template(self, name: str) -> str:
        """Load a template file."""
        path = self.view_dir / name
        if path.exists():
            return path.read_text()

        # Fallback to default
        default_path = self.view_dir / "default.html"
        if default_path.exists():
            return default_path.read_text()

        return "<div>{content}</div>"

    def _fill_template(
        self, template: str, frontmatter: dict, content_html: str
    ) -> str:
        """Fill template placeholders with values."""
        html = template

        # Replace {content}
        html = html.replace("{content}", content_html)

        # Replace frontmatter fields
        for key, value in frontmatter.items():
            placeholder = "{" + key + "}"
            if isinstance(value, list):
                value_str = ", ".join(str(v) for v in value)
            else:
                value_str = str(value) if value else ""
            html = html.replace(placeholder, value_str)

        # Handle homepage_link specially for projects
        if "{homepage_link}" in html:
            homepage = frontmatter.get("homepage", "").strip('"')
            if homepage:
                link = f'<a href="{homepage}" class="homepage">{homepage}</a>'
            else:
                link = ""
            html = html.replace("{homepage_link}", link)

        # Handle tags
        if "{tags}" in html:
            tags = frontmatter.get("tags", [])
            if tags:
                tags_html = " ".join(f'<span class="tag">{t}</span>' for t in tags)
            else:
                tags_html = ""
            html = html.replace("{tags}", tags_html)

        # Clean up any remaining placeholders
        html = re.sub(r"\{[a-z_]+\}", "", html)

        return html

    def _wrap_base(
        self,
        content: str,
        title: str,
        base_template_name: str = None,
        description: str = "",
        url_path: str = "",
    ) -> str:
        """Wrap content in base template."""
        if base_template_name:
            base_path = self.view_dir / base_template_name
            if base_path.exists():
                html = base_path.read_text()
            else:
                html = self.base_template
        else:
            html = self.base_template

        base_url = self.config.get("base_url", "").rstrip("/")
        full_url = f"{base_url}{url_path}" if url_path else base_url

        # Escape for HTML attributes and truncate
        description = description.replace('"', "&quot;").replace("\n", " ")[:160]

        html = html.replace("{content}", content)
        html = html.replace("{title}", title)
        html = html.replace("{description}", description)
        html = html.replace("{url}", full_url)
        return html

    def _markdown_to_html(
        self, text: str, collection: str = None, slug: str = None
    ) -> str:
        """Convert markdown to HTML (basic implementation)."""
        html = text

        # Process shortcodes first
        html = self._process_shortcodes(html)

        # Code blocks (do first to protect content)
        code_blocks = []

        def save_code_block(match):
            idx = len(code_blocks)
            lang = match.group(1) or ""
            code = match.group(2)
            code_blocks.append((lang, code))
            return f"__CODE_BLOCK_{idx}__"

        html = re.sub(r"```(\w*)\n(.*?)```", save_code_block, html, flags=re.DOTALL)

        # Inline code
        html = re.sub(r"`([^`]+)`", r"<code>\1</code>", html)

        # Headers
        html = re.sub(r"^### (.+)$", r"<h3>\1</h3>", html, flags=re.MULTILINE)
        html = re.sub(r"^## (.+)$", r"<h2>\1</h2>", html, flags=re.MULTILINE)
        html = re.sub(r"^# (.+)$", r"<h1>\1</h1>", html, flags=re.MULTILINE)

        # Bold and italic
        html = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html)
        html = re.sub(r"\*(.+?)\*", r"<em>\1</em>", html)

        # Images (handle relative paths) - must be before links
        def fix_image_path(match):
            alt = match.group(1)
            src = match.group(2)
            if src.startswith("./") and collection and slug:
                # Relative image - serve from data dir
                src = f"/data/{collection}/{slug}/{src[2:]}"
            return f'<img src="{src}" alt="{alt}">'

        html = re.sub(r"!\[([^\]]*)\]\(([^)]+)\)", fix_image_path, html)

        # Links
        html = re.sub(r"\[([^\]]+)\]\(([^)]+)\)", r'<a href="\2">\1</a>', html)

        # Blockquotes
        html = re.sub(
            r"^> (.+)$", r"<blockquote>\1</blockquote>", html, flags=re.MULTILINE
        )

        # Horizontal rules
        html = re.sub(r"^---+$", r"<hr>", html, flags=re.MULTILINE)

        # Lists (simple)
        html = re.sub(r"^- (.+)$", r"<li>\1</li>", html, flags=re.MULTILINE)
        html = re.sub(r"(<li>.*</li>\n?)+", r"<ul>\g<0></ul>", html)

        # Numbered lists
        html = re.sub(r"^\d+\. (.+)$", r"<li>\1</li>", html, flags=re.MULTILINE)

        # Tables
        html = self._convert_tables(html)

        # Paragraphs (wrap remaining text blocks)
        lines = html.split("\n\n")
        processed = []
        for line in lines:
            line = line.strip()
            if not line:
                continue
            if line.startswith("<"):
                processed.append(line)
            elif line.startswith("__CODE_BLOCK_"):
                processed.append(line)
            else:
                processed.append(f"<p>{line}</p>")
        html = "\n".join(processed)

        # Restore code blocks
        for idx, (lang, code) in enumerate(code_blocks):
            code_html = f'<pre><code class="language-{lang}">{self._escape_html(code)}</code></pre>'
            html = html.replace(f"__CODE_BLOCK_{idx}__", code_html)

        return html

    def _convert_tables(self, html: str) -> str:
        """Convert markdown tables to HTML."""
        lines = html.split("\n")
        result = []
        in_table = False
        table_lines = []

        for line in lines:
            if "|" in line and line.strip().startswith("|"):
                if not in_table:
                    in_table = True
                    table_lines = []
                table_lines.append(line)
            else:
                if in_table:
                    result.append(self._table_to_html(table_lines))
                    in_table = False
                    table_lines = []
                result.append(line)

        if in_table:
            result.append(self._table_to_html(table_lines))

        return "\n".join(result)

    def _table_to_html(self, lines: list) -> str:
        """Convert table lines to HTML."""
        if len(lines) < 2:
            return "\n".join(lines)

        rows = []
        for i, line in enumerate(lines):
            cells = [c.strip() for c in line.strip("|").split("|")]

            # Skip separator row
            if all(c.replace("-", "").replace(":", "") == "" for c in cells):
                continue

            tag = "th" if i == 0 else "td"
            row = "".join(f"<{tag}>{c}</{tag}>" for c in cells)
            rows.append(f"<tr>{row}</tr>")

        return f"<table>{''.join(rows)}</table>"

    def _render_feed(self, feed_config: dict) -> tuple[bytes, str]:
        """Render an RSS feed."""
        from datetime import datetime, timezone

        base_url = self.config.get("base_url", "").rstrip("/")
        collection = feed_config.get("collection")
        feed_path = feed_config.get("path", "/feed.xml")
        title = feed_config.get("title", collection)
        description = feed_config.get("description", "")
        limit = int(feed_config.get("limit", 20))

        # Get collection URL path
        coll_url_path = f"/{collection}"
        for coll in self.config.get("collections", []):
            if isinstance(coll, dict) and coll.get("name") == collection:
                coll_url_path = coll.get("path", f"/{collection}")
                break

        # Get entities with content
        client = DataClient()
        client.data_dir = self.data_dir
        client._schemas = {}
        client._load_schemas()

        entities = client.list_entities(collection, include_content=True)

        # Filter to those with dates and sort by date descending
        dated = []
        for e in entities:
            fm = e.get("frontmatter", {})
            date = fm.get("date") or fm.get("created")
            if date:
                dated.append((date, e))
        dated.sort(key=lambda x: x[0], reverse=True)
        dated = dated[:limit]

        # Build RSS
        lines = ['<?xml version="1.0" encoding="UTF-8"?>']
        lines.append('<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">')
        lines.append("<channel>")
        lines.append(f"  <title>{self._escape_xml(title)}</title>")
        lines.append(f"  <link>{base_url}{coll_url_path}</link>")
        lines.append(f"  <description>{self._escape_xml(description)}</description>")
        lines.append(
            f'  <atom:link href="{base_url}{feed_path}" rel="self" type="application/rss+xml"/>'
        )
        lines.append(
            f"  <lastBuildDate>{datetime.now(timezone.utc).strftime('%a, %d %b %Y %H:%M:%S +0000')}</lastBuildDate>"
        )

        for date, entity in dated:
            fm = entity.get("frontmatter", {})
            slug = entity.get("slug")
            item_title = fm.get("title", slug)
            item_url = f"{base_url}{coll_url_path}/{slug}"
            content = entity.get("content", "")

            # Render content to HTML
            content_html = self._markdown_to_html(content, collection, slug)

            # Format date
            try:
                dt = datetime.strptime(date, "%Y-%m-%d")
                rss_date = dt.strftime("%a, %d %b %Y 00:00:00 +0000")
            except ValueError:
                rss_date = date

            lines.append("  <item>")
            lines.append(f"    <title>{self._escape_xml(item_title)}</title>")
            lines.append(f"    <link>{item_url}</link>")
            lines.append(f"    <guid>{item_url}</guid>")
            lines.append(f"    <pubDate>{rss_date}</pubDate>")
            lines.append(f"    <description><![CDATA[{content_html}]]></description>")
            lines.append("  </item>")

        lines.append("</channel>")
        lines.append("</rss>")

        content = "\n".join(lines)
        return content.encode("utf-8"), "application/rss+xml; charset=utf-8"

    def _process_shortcodes(self, text: str) -> str:
        """Process Hugo-style shortcodes."""

        # Tweet embed: {{< tweet url="..." >}}
        def tweet_shortcode(match):
            url = match.group(1)
            return (
                f'<div class="embed tweet">'
                f'<blockquote class="twitter-tweet" data-dnt="true">'
                f'<a href="{url}">View tweet</a>'
                f"</blockquote>"
                f"</div>"
            )

        html = re.sub(r'\{\{<\s*tweet\s+url="([^"]+)"\s*>\}\}', tweet_shortcode, text)

        # Twitch embed: {{< twitch url="..." >}}
        def twitch_shortcode(match):
            url = match.group(1)
            return (
                f'<div class="embed twitch">'
                f'<iframe src="{url}" frameborder="0" allowfullscreen="true" '
                f'scrolling="no" height="378" width="620"></iframe>'
                f"</div>"
            )

        html = re.sub(r'\{\{<\s*twitch\s+url="([^"]+)"\s*>\}\}', twitch_shortcode, html)

        # YouTube embed: {{< youtube id="..." >}} or {{< youtube url="..." >}}
        def youtube_shortcode(match):
            param = match.group(1)
            value = match.group(2)
            if param == "id":
                video_id = value
            else:  # url
                # Extract video ID from various YouTube URL formats
                if "youtube.com/watch" in value:
                    video_id = value.split("v=")[1].split("&")[0]
                elif "youtu.be/" in value:
                    video_id = value.split("youtu.be/")[1].split("?")[0]
                elif "youtube.com/embed/" in value:
                    video_id = value.split("embed/")[1].split("?")[0]
                else:
                    video_id = value
            return (
                f'<div class="embed youtube">'
                f'<iframe width="560" height="315" '
                f'src="https://www.youtube-nocookie.com/embed/{video_id}" '
                f'frameborder="0" allowfullscreen></iframe>'
                f"</div>"
            )

        html = re.sub(
            r'\{\{<\s*youtube\s+(id|url)="([^"]+)"\s*>\}\}', youtube_shortcode, html
        )

        return html

    def _escape_xml(self, text: str) -> str:
        """Escape XML special characters."""
        return (
            str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    def _escape_html(self, text: str) -> str:
        """Escape HTML special characters."""
        return (
            text.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )
