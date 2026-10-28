import sys
import os

def parse_sprite(path):
    with open(path, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    sprite = []
    for line in lines:
        sprite.append([int(v.strip()) for v in line.split(",")])

    height = len(sprite)
    width = len(sprite[0]) if height > 0 else 0

    return sprite, width, height

def write_header(sprites, h_path):
    with open(h_path, "w") as f:
        f.write(f"""
                
#pragma once
#include <graphx.h>
#include <stdint.h>

""")

        # Write sprite data and pointers inline
        for name, (sprite, w, h) in sprites.items():
            f.write(f"// {name} ({w}x{h})\n")
            f.write(f"static unsigned char {name}_data[] = {{\n")
            f.write(f"    {w}, {h},\n")

            for y, row in enumerate(sprite):
                f.write("    ")
                f.write(", ".join(str(px & 0xFF) for px in row))
                if y < len(sprite) - 1:
                    f.write(",")
                f.write("\n")

            f.write("};\n")
            f.write(f"static gfx_sprite_t *{name}_sprite = (gfx_sprite_t*){name}_data;\n\n")
            f.write(f"#define {name.upper()}_WIDTH {w}\n")
            f.write(f"#define {name.upper()}_HEIGHT {h}\n\n")

def main():
    if len(sys.argv) < 3:
        print("Usage: python compilespritefolder.py sprite_folder output.h")
        sys.exit(1)

    sprite_dir = sys.argv[1]
    output = sys.argv[2]

    # Create output directory if one was specified
    output_dir = os.path.dirname(output)

    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    sprites = {}

    for file in os.listdir(sprite_dir):
        if not file.endswith(".sprite"):
            continue

        name = os.path.splitext(file)[0]
        path = os.path.join(sprite_dir, file)

        sprite, w, h = parse_sprite(path)
        sprites[name] = (sprite, w, h)

        print(f"Loaded {name} ({w}x{h})")

    if not sprites:
        print("No .sprite files found.")
        sys.exit(1)

    write_header(sprites, output)

    print(f"\nGenerated {output} with {len(sprites)} sprites (header-only)")

if __name__ == "__main__":
    main()
