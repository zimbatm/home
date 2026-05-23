#!/usr/bin/env python3
"""Entrypoint for the vendored zimbatm.com static-site builder.

Usage: build.py <view-name> <data-dir> <output-dir>
"""
import sys
from pathlib import Path

# Make `from toolbox...` imports resolve against the sibling `toolbox/` dir.
sys.path.insert(0, str(Path(__file__).parent))

from toolbox.data.tools.build import ViewBuilder


def main() -> int:
    if len(sys.argv) != 4:
        sys.exit(f"usage: {sys.argv[0]} <view-name> <data-dir> <output-dir>")
    view, data_dir, out_dir = sys.argv[1], Path(sys.argv[2]), Path(sys.argv[3])
    builder = ViewBuilder(view, data_dir, out_dir)
    stats = builder.build()
    print(
        f"built {view}: pages={stats['pages']} "
        f"assets={stats['assets']} bytes={stats['total_bytes']}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
