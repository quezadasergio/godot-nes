#!/usr/bin/env python3
"""Regenerate scripts/cover_registry.gd from game-images/*.import."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IMG = ROOT / "game-images"
OUT = ROOT / "scripts" / "cover_registry.gd"
EXTS = {".png", ".jpg", ".jpeg", ".webp"}


def parse_import(path: Path) -> tuple[str, str] | None:
    text = path.read_text(encoding="utf-8", errors="replace")
    uid_m = re.search(r'^uid="(uid://[^"]+)"', text, re.M)
    path_m = re.search(r'^path="(res://\.godot/imported/[^"]+\.ctex)"', text, re.M)
    if not uid_m or not path_m:
        return None
    return uid_m.group(1), path_m.group(1)


entries: list[tuple[str, str, str, str]] = []
for img in sorted(IMG.iterdir()):
    if img.suffix.lower() not in EXTS:
        continue
    imp = Path(str(img) + ".import")
    if not imp.is_file():
        print(f"skip (no .import): {img.name}")
        continue
    parsed = parse_import(imp)
    if not parsed:
        print(f"skip (bad .import): {img.name}")
        continue
    uid, ctex = parsed
    key = img.stem.lower().replace(" ", "_").replace("-", "_")
    entries.append((key, uid, ctex, f"res://game-images/{img.name}"))

lines = [
    "extends Object",
    "class_name CoverRegistry",
    "# Auto-generated from game-images/*.import",
    "# Run: python3 tools/gen_cover_registry.py",
    "",
    "# UID preloads survive export (source .jpg/.png paths are not packed, only .ctex).",
    "const TEXTURES: Dictionary = {",
]
for key, uid, _ctex, _src in entries:
    lines.append(f'\t"{key}": preload("{uid}"),')
lines += [
    "}",
    "",
    "# Direct .ctex paths as runtime fallback for web/PCK loads.",
    "const CTEX_PATHS: Dictionary = {",
]
for key, _uid, ctex, _src in entries:
    lines.append(f'\t"{key}": "{ctex}",')
lines += [
    "}",
    "",
    "static func texture_for(key: String) -> Texture2D:",
    "\tvar k := key.to_lower().strip_edges().replace(\" \", \"_\").replace(\"-\", \"_\")",
    "\tif TEXTURES.has(k):",
    "\t\tvar pre: Variant = TEXTURES[k]",
    "\t\tif pre is Texture2D:",
    "\t\t\treturn pre as Texture2D",
    "\tif CTEX_PATHS.has(k):",
    "\t\tvar path := String(CTEX_PATHS[k])",
    "\t\tif ResourceLoader.exists(path):",
    "\t\t\tvar loaded: Resource = ResourceLoader.load(path)",
    "\t\t\tif loaded is Texture2D:",
    "\t\t\t\treturn loaded as Texture2D",
    "\treturn null",
    "",
]
OUT.write_text("\n".join(lines) + "\n")
print(f"Wrote {OUT} ({len(entries)} covers)")
