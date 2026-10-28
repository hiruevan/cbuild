from PIL import Image
import sys
import os


def get_graphx_palette():
    """
    Generate the palette used by setup_xlibc_palette().

    Palette index:
        RRR GGG BB

    Red/green:
        3-bit -> 5-bit

    Blue:
        2-bit -> 5-bit

    The resulting 5-bit channels are expanded to 8-bit
    so they can be compared against Pillow RGB values.
    """
    palette = []

    for i in range(256):
        # Extract packed palette components
        r3 = (i >> 5) & 0x07
        g3 = (i >> 2) & 0x07
        b2 = i & 0x03

        # Match the C code exactly:
        #
        # r = (r << 2) | (r >> 1);
        # g = (g << 2) | (g >> 1);
        # b = (b << 3) | (b << 1) | (b >> 1);

        r5 = (r3 << 2) | (r3 >> 1)
        g5 = (g3 << 2) | (g3 >> 1)
        b5 = (b2 << 3) | (b2 << 1) | (b2 >> 1)

        # Convert 5-bit values to 8-bit RGB for Pillow.
        #
        # Use bit replication, matching the style of the
        # C conversion rather than simple multiplication.
        r8 = (r5 << 3) | (r5 >> 2)
        g8 = (g5 << 3) | (g5 >> 2)
        b8 = (b5 << 3) | (b5 >> 2)

        palette.append((r8, g8, b8))

    return palette


def find_closest_palette_index(r, g, b, palette):
    """Find the closest color in the TI-84 CE palette."""
    min_dist = float("inf")
    closest_idx = 0

    for idx, (pr, pg, pb) in enumerate(palette):
        dist = (
            (r - pr) ** 2 +
            (g - pg) ** 2 +
            (b - pb) ** 2
        )

        if dist < min_dist:
            min_dist = dist
            closest_idx = idx

    return closest_idx


def image_to_sprite(image_path, out_path, palette, width=None, height=None):
    """Convert one image to a .sprite file."""

    img = Image.open(image_path).convert("RGB")

    if width is not None and height is not None:
        img = img.resize((width, height), Image.NEAREST)

    w, h = img.size
    pixels = img.load()

    with open(out_path, "w") as f:
        for y in range(h):
            row = []

            for x in range(w):
                r, g, b = pixels[x, y]

                ti_col = find_closest_palette_index(
                    r, g, b, palette
                )

                row.append(str(ti_col))

            f.write(", ".join(row) + "\n")

    print(
        f"Converted {os.path.basename(image_path)} "
        f"â†’ {os.path.basename(out_path)} ({w}x{h})"
    )


def main():

    if len(sys.argv) < 3:
        print("Usage:")
        print(
            "  python createspritefolder.py "
            "input_folder output_folder [width height]"
        )
        sys.exit(1)

    input_folder = sys.argv[1]
    output_folder = sys.argv[2]

    # Optional resize dimensions
    width = None
    height = None

    if len(sys.argv) == 5:
        width = int(sys.argv[3])
        height = int(sys.argv[4])

    # Verify input folder
    if not os.path.isdir(input_folder):
        print(f"Error: Input folder does not exist: {input_folder}")
        sys.exit(1)

    # Create output folder
    os.makedirs(output_folder, exist_ok=True)

    # Generate the exact TI-84 CE palette
    palette = get_graphx_palette()

    image_extensions = {
        ".png",
        ".jpg",
        ".jpeg",
        ".bmp",
        ".gif"
    }

    converted = 0

    # Process every image in the folder
    for filename in os.listdir(input_folder):

        input_path = os.path.join(input_folder, filename)

        # Ignore directories
        if not os.path.isfile(input_path):
            continue

        extension = os.path.splitext(filename)[1].lower()

        # Ignore non-image files
        if extension not in image_extensions:
            continue

        # Remove extension
        name = os.path.splitext(filename)[0]

        # Create output filename
        output_path = os.path.join(
            output_folder,
            name + ".sprite"
        )

        try:
            image_to_sprite(
                input_path,
                output_path,
                palette,
                width,
                height
            )

            converted += 1

        except Exception as e:
            print(f"Failed to convert {filename}: {e}")

    print()
    print(f"Converted {converted} image(s).")
    print(f"Output folder: {output_folder}")


if __name__ == "__main__":
    main()
