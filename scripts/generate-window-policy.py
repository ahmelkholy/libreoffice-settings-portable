#!/usr/bin/env python3
"""Generate immutable no-toolbar configuration files from LibreOffice schemas."""

from __future__ import annotations

import argparse
import html
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

OOR = "http://openoffice.org/2001/registry"
PACKAGE = "org.openoffice.Office.UI"
ZOTERO_TOOLBAR = "private:resource/toolbar/addon_Zotero.OfficeToolBar"


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "registry_dir",
        type=Path,
        help="LibreOffice registry directory containing .xcd files",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "extension" / "clean-ui",
    )
    return parser.parse_args()


def collect_toolbars(registry_dir: Path) -> dict[str, set[str]]:
    components: dict[str, set[str]] = {}
    for source in sorted(registry_dir.glob("*.xcd")):
        tree = ET.parse(source)
        for component in tree.iter(f"{{{OOR}}}component-data"):
            name = component.get(f"{{{OOR}}}name")
            package = component.get(f"{{{OOR}}}package")
            if package != PACKAGE or not name or not name.endswith("WindowState"):
                continue
            for node in component.iter("node"):
                resource = node.get(f"{{{OOR}}}name", "")
                if resource.startswith("private:resource/toolbar/"):
                    components.setdefault(name, set()).add(resource)

    for toolbars in components.values():
        toolbars.add(ZOTERO_TOOLBAR)
    return components


def render_component(name: str, toolbars: set[str]) -> str:
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        "<oor:component-data",
        f'    xmlns:oor="{OOR}"',
        '    xmlns:xs="http://www.w3.org/2001/XMLSchema"',
        f'    oor:name="{html.escape(name, quote=True)}"',
        f'    oor:package="{PACKAGE}">',
        '  <node oor:name="UIElements">',
        '    <node oor:name="States">',
    ]
    for resource in sorted(toolbars):
        escaped = html.escape(resource, quote=True)
        lines.extend(
            [
                f'      <node oor:name="{escaped}">',
                '        <prop oor:name="Visible" oor:finalized="true">',
                "          <value>false</value>",
                "        </prop>",
                '        <prop oor:name="ContextSensitive" oor:finalized="true">',
                "          <value>false</value>",
                "        </prop>",
                '        <prop oor:name="HideFromToolbarMenu" oor:finalized="true">',
                "          <value>true</value>",
                "        </prop>",
            ]
        )
        lines.append("      </node>")
    lines.extend(
        [
            "    </node>",
            "  </node>",
            "</oor:component-data>",
            "",
        ]
    )
    return "\n".join(lines)


def render_manifest(component_names: list[str]) -> str:
    entries = ["ToolbarMode.xcu", "Views.xcu", "Writer.xcu"] + [
        f"{name}.xcu" for name in component_names
    ]
    lines = [
        '<?xml version="1.0" encoding="UTF-8"?>',
        '<manifest:manifest xmlns:manifest="http://openoffice.org/2001/manifest">',
        "  <manifest:file-entry",
        '      manifest:full-path="pkg-desc/pkg-description.txt"',
        '      manifest:media-type="application/vnd.sun.star.package-bundle-description"/>',
    ]
    for entry in entries:
        lines.extend(
            [
                "  <manifest:file-entry",
                f'      manifest:full-path="{html.escape(entry, quote=True)}"',
                '      manifest:media-type="application/vnd.sun.star.configuration-data"/>',
            ]
        )
    lines.extend(["</manifest:manifest>", ""])
    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    if not args.registry_dir.is_dir():
        print(f"Registry directory not found: {args.registry_dir}", file=sys.stderr)
        return 1

    components = collect_toolbars(args.registry_dir)
    if not components:
        print("No LibreOffice window-state toolbar definitions found.", file=sys.stderr)
        return 1

    args.output_dir.mkdir(parents=True, exist_ok=True)
    for old_file in args.output_dir.glob("*WindowState.xcu"):
        old_file.unlink()
    for name, toolbars in sorted(components.items()):
        destination = args.output_dir / f"{name}.xcu"
        destination.write_text(render_component(name, toolbars), encoding="utf-8")
    manifest = args.output_dir / "META-INF" / "manifest.xml"
    manifest.write_text(render_manifest(sorted(components)), encoding="utf-8")

    toolbar_count = sum(len(toolbars) for toolbars in components.values())
    print(f"Generated {len(components)} window-state files for {toolbar_count} toolbar entries.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
