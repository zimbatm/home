"""Build a view to static files."""

import shutil
from pathlib import Path

from toolbox.data.client import DataClient
from toolbox.data.renderer import ViewRenderer


class ViewBuilder:
    """Builds a view to static files."""

    def __init__(self, view_name: str, data_dir: Path, output_dir: Path):
        self.view_name = view_name
        self.data_dir = data_dir
        self.output_dir = output_dir
        self.renderer = ViewRenderer(view_name, data_dir)
        self.stats = {"pages": 0, "assets": 0, "total_bytes": 0}

    def build(self) -> dict:
        """Build the entire site."""
        # Clean output dir
        if self.output_dir.exists():
            shutil.rmtree(self.output_dir)
        self.output_dir.mkdir(parents=True)

        # Build all routes
        self._build_pages()

        # Copy static assets from view
        self._copy_view_assets()

        # Copy data assets (images in collections)
        self._copy_data_assets()

        # Build alias pages
        self._build_aliases()

        # Generate sitemap
        self._build_sitemap()

        # Generate RSS feeds
        self._build_feeds()

        return self.stats

    def _build_pages(self):
        """Build all HTML pages."""
        # Build explicit pages
        for page in self.renderer.config.get("pages", []):
            if isinstance(page, dict):
                path = page.get("path", "/")
                self._build_path(path)

        # Build collection pages
        for coll in self.renderer.config.get("collections", []):
            if isinstance(coll, dict):
                name = coll.get("name")
                url_path = coll.get("path", f"/{name}")

                # Build list page
                self._build_path(url_path)

                # Build item pages
                self._build_collection_items(name, url_path)

    def _build_collection_items(self, collection: str, url_path: str):
        """Build all items in a collection."""
        client = DataClient()
        client.data_dir = self.data_dir
        client._schemas = {}
        client._load_schemas()

        entities = client.list_entities(collection)
        for entity in entities:
            slug = entity.get("slug")
            item_path = f"{url_path}/{slug}"
            self._build_path(item_path)

    def _build_path(self, url_path: str):
        """Build a single path to HTML file."""
        content, content_type = self.renderer.render_path(url_path)
        if content is None:
            print(f"  Warning: Could not render {url_path}")
            return

        # Determine output file path
        if url_path == "/":
            file_path = self.output_dir / "index.html"
        elif url_path.endswith(".html"):
            file_path = self.output_dir / url_path.lstrip("/")
        else:
            file_path = self.output_dir / url_path.lstrip("/") / "index.html"

        file_path.parent.mkdir(parents=True, exist_ok=True)
        file_path.write_bytes(content)

        self.stats["pages"] += 1
        self.stats["total_bytes"] += len(content)

    def _copy_view_assets(self):
        """Copy static assets from view directory."""
        view_dir = self.data_dir / "views" / self.view_name

        for path in view_dir.rglob("*"):
            if path.is_file() and not path.name.endswith((".md", ".html")):
                rel = path.relative_to(view_dir)
                dest = self.output_dir / rel
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, dest)
                self.stats["assets"] += 1
                self.stats["total_bytes"] += path.stat().st_size

    def _copy_data_assets(self):
        """Copy assets (images) from data collections."""
        for coll in self.renderer.config.get("collections", []):
            if isinstance(coll, dict):
                name = coll.get("name")
                url_path = coll.get("path", f"/{name}")
                coll_dir = self.data_dir / name

                if not coll_dir.exists():
                    continue

                # Find all non-md, non-yaml files
                for path in coll_dir.rglob("*"):
                    if path.is_file() and path.suffix not in (".md", ".yaml"):
                        # Determine relative path within collection
                        rel = path.relative_to(coll_dir)
                        dest = self.output_dir / url_path.lstrip("/") / rel

                        dest.parent.mkdir(parents=True, exist_ok=True)
                        shutil.copy2(path, dest)
                        self.stats["assets"] += 1
                        self.stats["total_bytes"] += path.stat().st_size

    def _build_aliases(self):
        """Build pages for URL aliases."""
        for from_path, to_path in self.renderer.aliases.items():
            # Render the target path but save at the alias path
            content, content_type = self.renderer.render_path(to_path)
            if content is None:
                print(f"  Warning: Alias target not found: {to_path}")
                continue

            # Determine output file path
            file_path = self.output_dir / from_path.lstrip("/") / "index.html"
            file_path.parent.mkdir(parents=True, exist_ok=True)
            file_path.write_bytes(content)

            self.stats["pages"] += 1
            self.stats["total_bytes"] += len(content)

    def _build_sitemap(self):
        """Generate sitemap.xml."""
        base_url = self.renderer.config.get("base_url", "").rstrip("/")

        # Collect all URLs
        urls = []
        for path in self.output_dir.rglob("index.html"):
            rel = path.relative_to(self.output_dir)
            url_path = "/" + str(rel.parent)
            if url_path == "/.":
                url_path = "/"
            urls.append(f"{base_url}{url_path}")

        urls.sort()

        # Generate XML
        lines = ['<?xml version="1.0" encoding="UTF-8"?>']
        lines.append('<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">')
        for url in urls:
            lines.append(f"  <url><loc>{url}</loc></url>")
        lines.append("</urlset>")

        sitemap_path = self.output_dir / "sitemap.xml"
        content = "\n".join(lines)
        sitemap_path.write_text(content)

        self.stats["assets"] += 1
        self.stats["total_bytes"] += len(content)

    def _build_feeds(self):
        """Generate RSS feeds."""
        from datetime import datetime

        base_url = self.renderer.config.get("base_url", "").rstrip("/")

        for feed_config in self.renderer.config.get("feeds", []):
            if not isinstance(feed_config, dict):
                continue

            collection = feed_config.get("collection")
            feed_path = feed_config.get("path", "/feed.xml")
            title = feed_config.get("title", collection)
            description = feed_config.get("description", "")
            limit = int(feed_config.get("limit", 20))

            # Get collection URL path
            coll_url_path = f"/{collection}"
            for coll in self.renderer.config.get("collections", []):
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
            lines.append(
                f"  <description>{self._escape_xml(description)}</description>"
            )
            lines.append(
                f'  <atom:link href="{base_url}{feed_path}" rel="self" type="application/rss+xml"/>'
            )
            lines.append(
                f"  <lastBuildDate>{datetime.utcnow().strftime('%a, %d %b %Y %H:%M:%S +0000')}</lastBuildDate>"
            )

            for date, entity in dated:
                fm = entity.get("frontmatter", {})
                slug = entity.get("slug")
                item_title = fm.get("title", slug)
                item_url = f"{base_url}{coll_url_path}/{slug}"
                content = entity.get("content", "")

                # Render content to HTML
                content_html = self.renderer._markdown_to_html(
                    content, collection, slug
                )

                lines.append("  <item>")
                lines.append(f"    <title>{self._escape_xml(item_title)}</title>")
                lines.append(f"    <link>{item_url}</link>")
                lines.append(f"    <guid>{item_url}</guid>")
                lines.append(f"    <pubDate>{self._format_rss_date(date)}</pubDate>")
                lines.append(
                    f"    <description><![CDATA[{content_html}]]></description>"
                )
                lines.append("  </item>")

            lines.append("</channel>")
            lines.append("</rss>")

            feed_file = self.output_dir / feed_path.lstrip("/")
            feed_file.parent.mkdir(parents=True, exist_ok=True)
            content = "\n".join(lines)
            feed_file.write_text(content)

            self.stats["assets"] += 1
            self.stats["total_bytes"] += len(content)

    def _escape_xml(self, text: str) -> str:
        """Escape XML special characters."""
        return (
            str(text)
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace('"', "&quot;")
        )

    def _format_rss_date(self, date_str: str) -> str:
        """Convert YYYY-MM-DD to RSS date format."""
        from datetime import datetime

        try:
            dt = datetime.strptime(date_str, "%Y-%m-%d")
            return dt.strftime("%a, %d %b %Y 00:00:00 +0000")
        except ValueError:
            return date_str
