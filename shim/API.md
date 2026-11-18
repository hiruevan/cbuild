# Shim API

The same names work on every platform.

| Platform | Where the API comes from |
|---|---|
| Windows / Linux / Webpage | `shim/include` headers, implemented in `shim/desk` |
| GameCube | `shim/include` headers, implemented in `shim/gc` |
| Calculator (TI-84 CE) | `shim/calc` headers, thin aliases onto CEdev (`graphx`, `fileioc`, `tice`) |
| All | header-only helpers in `shim/common`; `input.h` is generated per project (last section) |

---

## graphics.h

### Types and constants

| Name | Meaning |
|---|---|
| `Point` | `{ int x; int y; }` |
| `Sprite` | `{ uint8_t width; uint8_t height; uint8_t data[]; }` (palette indices) |
| `Tilemap` | Tilemap description (was `gfx_tilemap_t`) |
| `TilemapType` | Tile size selector. Values: `TILE_NO_POW2`, `TILE_2_PIXEL` ... `TILE_128_PIXEL` |
| `DrawLocation` | Draw target. Values: `LOC_SCREEN`, `LOC_BUFFER` |
| `GraphicsMode` | Values: `MODE_8BPP` |
| `LCD_WIDTH`, `LCD_HEIGHT` | Screen size (320 x 240) |
| `Palette[256]` | The palette, 16-bit 1555 entries |
| `RGBTo1555(r, g, b)` | 8-bit-per-channel color to a 1555 palette entry |
| `TempSprite`, `UninitedSprite`, `AllocSprite`, `MallocSprite` | Sprite allocation helpers |

### Naming rule

| Old | New |
|---|---|
| `gfx_Xxx` | `Xxx` (for example `gfx_FillRectangle` -> `FillRectangle`) |
| `gfx_Begin`, `gfx_End` | `DrawBegin`, `DrawEnd` |
| `gfx_ShiftLeft` / `Right` / `Up` / `Down` | `LCDShiftLeft` / `Right` / `Up` / `Down` |
| `gfx_Sprite`, `gfx_Sprite_NoClip` | `DrawSprite`, `DrawSprite_NoClip` |
| `gfx_TransparentSprite`, `..._NoClip` | `DrawTransparentSprite`, `..._NoClip` |
| `gfx_ScaledSprite_NoClip`, `gfx_ScaledTransparentSprite_NoClip` | `DrawScaledSprite_NoClip`, `DrawScaledTransparentSprite_NoClip` |
| `gfx_Tilemap`, `gfx_TransparentTilemap` (and `_NoClip`) | `DrawTilemap`, `DrawTransparentTilemap` (and `_NoClip`) |
| `gfx_palette` | `Palette` |

The sprite and tilemap draw calls are renamed because a function called `Sprite` or `Tilemap` cannot share a name with the type.

### Functions

| Group | Functions |
|---|---|
| Setup | `DrawBegin`, `DrawEnd`, `SetPalette`, `SetDefaultPalette` |
| Draw target | `SetDraw`, `GetDraw`, `SetDrawScreen`, `SetDrawBuffer`, `SwapDraw`, `Wait`, `Blit`, `BlitBuffer`, `BlitScreen` |
| State | `SetColor`, `SetTransparentColor`, `SetClipRegion`, `FillScreen`, `ZeroScreen` |
| Pixels and shapes | `SetPixel`, `GetPixel`, `Line`, `HorizLine`, `VertLine`, `Rectangle`, `FillRectangle`, `Circle`, `FillCircle` (each also has a `_NoClip` version, except `SetPixel` / `GetPixel`) |
| Sprites | `DrawSprite`, `DrawTransparentSprite`, `DrawScaledSprite_NoClip`, `DrawScaledTransparentSprite_NoClip`, `GetSprite`, `FlipSpriteX`, `FlipSpriteY` |
| Tilemaps | `DrawTilemap`, `DrawTransparentTilemap` (and `_NoClip`) |
| Text | `PrintChar`, `PrintInt`, `PrintUInt`, `PrintString`, `PrintStringXY`, `SetTextXY`, `GetTextX`, `GetTextY`, `SetTextFGColor`, `SetTextBGColor`, `SetTextTransparentColor`, `SetTextScale`, `GetStringWidth`, `GetCharWidth` |
| LCD scrolling | `LCDShiftLeft`, `LCDShiftRight`, `LCDShiftUp`, `LCDShiftDown` |

### Extras (same code on every platform)

| Name | Meaning |
|---|---|
| `SwapPoint(a, b)` | Swap two `Point`s through pointers |
| `Triangle(a, b, c)` | Outline triangle in the current color |
| `FillTriangle(a, b, c)` | Filled triangle (scanline), clipped like `HorizLine` |
| `RGBTo255(r, g, b)` | Nearest index in the xLibC palette for an 8-bit-per-channel color |
| `setup_xlibc_palette()` | Load the xLibC palette (index = RRRGGGBB) |
| `setup_default_palette()` | Same as `setup_xlibc_palette()` |
| `setup_grayscale_palette()` | 256 evenly spaced grays |
| `setup_web_palette()` | 6x6x6 web-safe color cube (0-215), then 40 grays |

---

## files.h

| Name | Meaning |
|---|---|
| `OpenFile(name, mode)` | Open a file; returns a slot number, or 0 on failure |
| `CloseFile(slot)` | Close a slot |
| `ReadFile(data, size, count, slot)` | Read `count` items of `size` bytes; returns items read |
| `WriteFile(data, size, count, slot)` | Write `count` items of `size` bytes; returns items written |
| `DeleteFile(name)` | Delete a file |
| `FileExists(name)` | True if the file can be opened for reading |
| `PutFileChar(c, slot)` / `GetFileChar(slot)` | Write / read one byte |
| `SeekFile(offset, origin, slot)` | Move the file position |
| `TellFile(slot)` | Current file position |
| `RewindFile(slot)` | Go back to the start |
| `FileSize(slot)` | File size in bytes |
| `GetFileDataPtr(slot)` | Pointer to the file's data at the current position |

Not usable together with `<windows.h>`: `OpenFile`, `ReadFile`, `WriteFile` and `DeleteFile` clash with Win32 names, and `graphics.h` has the same problem with `Rectangle`. Both headers stop with a clear error if `<windows.h>` is already included.

---

## random.h

| Name | Meaning |
|---|---|
| `random()`, `srandom(seed)` | Basic generator. Provided by libc / `tice.h`; defined by the shim on Windows only |
| `uint24_t`, `int24_t` | The calculator's 24-bit types (32-bit elsewhere) |
| `RandomRange(lo, hi)` | Random integer, both ends inclusive |
| `RandomChance(percent)` | True `percent` percent of the time (0-100) |
| `RandomFloat()` | Random float in [0, 1) |
| `HashU32(x)`, `Hash2D(x, y, seed)` | Deterministic integer hashes |
| `ValueNoise2D(x, y, seed)` | Smooth value noise, 0 to 1 |
| `PerlinNoise2D(x, y, seed)` | Gradient (Perlin) noise, about -1 to 1 |
| `FractalNoise2D(x, y, seed, octaves)` | Several octaves of Perlin noise, about -1 to 1 |

The noise functions give the same result on every platform for the same inputs.

---

## input.h (generated per project)

`generateinputs.py` writes `build/<platform>/input.h` and `input.c` from `resources/keybinds.cfg`. The calculator build uses keypadc, desktop uses the SDL keyboard, and pads use SDL game controllers. Games only include `<input.h>`.

### Types and constants

| Name | Meaning |
|---|---|
| `InputAction` | One logical action: `id` (internal index) and `name` (label for the active device, such as "2nd", "Space" or "A", for on-screen hints) |
| `InputBindings` | Struct with one `InputAction` field per `DEF` line, plus `AnyKey` |
| `INPUT` | The one global `InputBindings`. Use `INPUT.ActionKey`, `INPUT.UpKey`, and so on |
| `INPUT_ACTION_COUNT` | Number of actions (the `DEF` lines plus `AnyKey`) |
| `INPUT_PROMPT_MAX` | Longest string `TextPrompt` can return (32) |

### Functions

| Name | Meaning |
|---|---|
| `Input_Scan()` | Read the hardware once. Call once per frame before any `KeyDown` / `KeyJustPressed`. On desktop it also pumps SDL events, handles the window close button and presents the frame |
| `KeyDown(action)` | True while any key bound to the action is held |
| `KeyJustPressed(action)` | True only on the first scan after the key goes down |
| `AnyKeyDown()` | Intended: true if any bound key is held. Currently a stub that returns false, so do not rely on it |
| `TextPrompt(txt, maxChars)` | Blocking text entry. `txt` is the label shown to the user; `maxChars` is clamped to `INPUT_PROMPT_MAX` (also used when 0 or less). Returns a pointer to an internal buffer that the next call overwrites (copy it if you need it), or `NULL` if the user cancelled. Uses the on-screen keyboard on calculator and gamepad. Calls `Input_Scan()` twice on exit so the confirming keypress is not seen again |
| `TextPromptSetColors(fg, bg)` | Palette indices the prompt draws with |
| `TextPromptSetRestore(color, fg, bg, transparent)` | Drawing state put back when the prompt closes: draw color, text foreground, text background and text transparent index. Set once at startup to your game's normal values |

Typical frame:

```c
Input_Scan();
if (KeyJustPressed(INPUT.ActionKey)) { /* confirm */ }
if (KeyDown(INPUT.LeftKey))          { /* move left while held */ }
```

### keybinds.cfg structure

The file has two parts: first the list of actions, then one block of bindings per device type. Everything after `#` on a line is a comment, and blank lines are ignored.

| Part | Syntax | Rules |
|---|---|---|
| Action list | `DEF ActionName` | One per action, outside any block. The name must be a valid C identifier. It becomes the `INPUT.ActionName` field. `AnyKey` is reserved and is added automatically. At least one `DEF` is required; duplicates are an error |
| Device block | `CALCULATOR { ... }`, `KEYBOARD { ... }`, `GAMEPAD { ... }`, `MOBILE { ... }` | Each block appears at most once and cannot be nested. Which blocks are used depends on the platform (next table) |
| Binding line | `ActionName = Key_A, Key_B` | Inside a block. Several comma-separated keys are alternatives for the same action. Every `DEF` action needs a line in every block you write, and every line must have a matching `DEF` |
| Unbound | `ActionName = NONE` | Use when an action intentionally has no binding on that device. `NONE` cannot be combined with other keys |
| Key names | `Key_...`, `Pad_...`, `Touch_...` | `Key_` for calculator and keyboard keys, `Pad_` for gamepad buttons and sticks (for example `Pad_A`, `Pad_Left_Pos_Y`), `Touch_` for mobile |

Which blocks each platform uses:

| Platform | Blocks used |
|---|---|
| `cal` | `CALCULATOR` |
| `win`, `lnx` (and `lnx-x86_64`, `lnx-aarch64`, `lnx-armhf`) | `KEYBOARD`, `GAMEPAD` |
| `webp` | `KEYBOARD`, `GAMEPAD`, `MOBILE` |
| `gc` | `GAMEPAD` |
| `mac`, `android`, `ios` | Planned, not implemented yet |

Optional properties go on indented lines directly under a binding line:

| Property | Meaning |
|---|---|
| `.name = "text"` | Label shown for the action. Defaults to the first key. Must be in quotes |
| `.name.<platform> = "text"` | Label on one platform only (for example `.name.gc = "Start"`) |
| `.<platform> = Key, Key` | Different bindings on one platform inside a shared block (for example `.gc = Pad_X`). A short name like `.lnx` also covers `lnx-x86_64` and the other Linux variants |
| `.pos = x, y` | Screen position for on-screen controls, two numbers from 0 to 1. Cannot be set per platform |

Platform names for `.<platform>` and `.name.<platform>` come from the platform table above.

Example:

```
DEF ActionKey
DEF UpKey

KEYBOARD {
    ActionKey = Key_Space, Key_Z    # two keys, one action
        .name = "Space"
    UpKey = Key_Arrow_Up, Key_W
}

GAMEPAD {
    ActionKey = Pad_A
        .name.gc = "A"
    UpKey = Pad_Up, Pad_Left_Pos_Y
}
```