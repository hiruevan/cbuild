from PIL import Image
import sys
import os


def get_ti84_palette():
    """
    Generates the exact palette used by setup_xlibc_palette().

    Palette index:
        RRR GGG BB

    Red/green:
        3-bit -> 5-bit

    Blue:
        2-bit -> 5-bit

    The 5-bit values are then expanded to 8-bit RGB
    for use by Pillow.
    """
    palette = []

    for i in range(256):
        # Extract RRRGGGBB
        r3 = (i >> 5) & 0x07
        g3 = (i >> 2) & 0x07
        b2 = i & 0x03

        # Match setup_xlibc_palette() exactly:
        #
        # r = (r << 2) | (r >> 1);
        # g = (g << 2) | (g >> 1);
        # b = (b << 3) | (b << 1) | (b >> 1);

        r5 = (r3 << 2) | (r3 >> 1)
        g5 = (g3 << 2) | (g3 >> 1)
        b5 = (b2 << 3) | (b2 << 1) | (b2 >> 1)

        # Expand 5-bit RGB to 8-bit RGB for Pillow.
        r8 = (r5 << 3) | (r5 >> 2)
        g8 = (g5 << 3) | (g5 >> 2)
        b8 = (b5 << 3) | (b5 >> 2)

        palette.extend((r8, g8, b8))

    return palette


def sprite_to_png(sprite_path, out_path, scale=1):
    try:
        with open(sprite_path, "r") as f:
            lines = [line.strip() for line in f if line.strip()]

        if not lines:
            print(
                f"Skipped {os.path.basename(sprite_path)}: "
                f"empty file"
            )
            return False

        # Convert text indices into rows
        rows = []

        for line in lines:
            row = [
                int(v.strip())
                for v in line.split(",")
                if v.strip()
            ]

            if row:
                rows.append(row)

        if not rows:
            print(
                f"Skipped {os.path.basename(sprite_path)}: "
                f"no pixel data"
            )
            return False

        # Make sure every row has the same width
        width = len(rows[0])

        for row in rows:
            if len(row) != width:
                print(
                    f"Skipped {os.path.basename(sprite_path)}: "
                    f"inconsistent row widths"
                )
                return False

        height = len(rows)

        # Flatten pixel data
        data = []

        for row in rows:
            data.extend(row)

        # Validate palette indices
        for index in data:
            if index < 0 or index > 255:
                print(
                    f"Skipped {os.path.basename(sprite_path)}: "
                    f"invalid palette index {index}"
                )
                return False

        # Create palette-based image
        img = Image.new("P", (width, height))

        # Load exact TI-84 CE palette
        img.putpalette(get_ti84_palette())

        # Put raw palette indices into image
        img.putdata(data)

        # Convert using the palette
        img = img.convert("RGB")

        # Optional scaling
        if scale > 1:
            img = img.resize(
                (width * scale, height * scale),
                Image.NEAREST
            )

        img.save(out_path)

        print(
            f"Converted {os.path.basename(sprite_path)} "
            f"â†’ {os.path.basename(out_path)} "
            f"({width}x{height})"
        )

        return True

    except Exception as e:
        print(
            f"Error processing "
            f"{os.path.basename(sprite_path)}: {e}"
        )
        return False


def main():
    if len(sys.argv) < 3:
        print(
            "Usage: python spritetopngfolder.py "
            "input_folder output_folder [scale]"
        )
        sys.exit(1)

    input_folder = sys.argv[1]
    output_folder = sys.argv[2]

    # Optional scale
    scale = int(sys.argv[3]) if len(sys.argv) >= 4 else 1

    # Validate scale
    if scale < 1:
        print("Error: scale must be at least 1.")
        sys.exit(1)

    # Check input folder
    if not os.path.isdir(input_folder):
        print(
            f"Error: input folder does not exist: "
            f"{input_folder}"
        )
        sys.exit(1)

    # Create output folder
    os.makedirs(output_folder, exist_ok=True)

    converted = 0
    skipped = 0

    # Process every file in the folder
    for filename in os.listdir(input_folder):

        input_path = os.path.join(input_folder, filename)

        # Ignore directories
        if not os.path.isfile(input_path):
            continue

        # Only process .sprite files
        if not filename.lower().endswith(".sprite"):
            continue

        # Change .sprite -> .png
        name = os.path.splitext(filename)[0]

        output_path = os.path.join(
            output_folder,
            name + ".png"
        )

        if sprite_to_png(input_path, output_path, scale):
            converted += 1
        else:
            skipped += 1

    print()
    print(f"Converted: {converted}")
    print(f"Skipped:   {skipped}")
    print(f"Output:    {output_folder}")


if __name__ == "__main__":
    main()
