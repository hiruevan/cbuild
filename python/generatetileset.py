import re
import sys
from pathlib import Path

# Matches: static gfx_sprite_t *NAME_sprite = (gfx_sprite_t*)NAME_data;
SPRITE_RE = re.compile(
    r'static\s+gfx_sprite_t\s*\*\s*(\w+)_sprite\s*='
)


def extract_sprite_names(text: str) -> list[str]:
    """Return sprite base names in the order they appear in the file."""
    names = SPRITE_RE.findall(text)
    # de-dupe while preserving order, just in case
    seen = set()
    ordered = []
    for n in names:
        if n not in seen:
            seen.add(n)
            ordered.append(n)
    return ordered


def build_tileset_h(names: list[str], spritefile: str) -> str:
    lines = []

    lines.append("#ifndef TILESET_H")
    lines.append("#define TILESET_H")
    lines.append("")
    lines.append(f'#pragma once')
    lines.append(f'#include "../libs/tiles.h"')
    lines.append(f'#include "{spritefile.split(".")[0]}.h"')
    lines.append("")
    lines.append("Tile tileset[MAX_TILES];")
    lines.append("")
    lines.append("void loadTileset() {")
    lines.append("    tiles_init(tileset);")
    lines.append("")

    for i, name in enumerate(names):
        lines.append(f"    tiles_set(tileset, {i}, {name}_sprite);")

    lines.append("}")
    lines.append("")
    lines.append("#endif")
    lines.append("")
    lines.append("/* ")
    lines.append("const TILE_NAMES = [" + ",".join(f"'{n}'" for n in names) + "];")
    lines.append("*/")
    lines.append("")

    return "\n".join(lines)


def main():
    if len(sys.argv) < 2:
        print("Usage: python generate_tileset.py <sprites.h> [tileset.h]")
        sys.exit(1)

    src_path = Path(sys.argv[1])
    if len(sys.argv) >= 3:
        dst_path = Path(sys.argv[2])
    else:
        dst_path = src_path.with_name("tileset.h")

    text = src_path.read_text()
    names = extract_sprite_names(text)

    if not names:
        print("No sprites found (looking for 'static gfx_sprite_t *NAME_sprite = ...').")
        sys.exit(1)
    print(src_path.name)
    output = build_tileset_h(names, src_path.name)
    dst_path.write_text(output)

    print(f"Found {len(names)} sprites.")
    print(f"Wrote {dst_path}")


if __name__ == "__main__":
    main()
