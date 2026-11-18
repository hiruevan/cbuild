# Shim API (graphics.h / files.h / random.h)

Same names on every platform. Desktop/GameCube: shim/include + shim/desk|gc.
Calculator: shim/calc forwards to CEdev (graphx / fileioc / tice). Shared header-only
helpers live in shim/common. Input is generated per project (input.h), not shimmed.

## graphics.h
Types: Point, Sprite, Tilemap, DrawLocation (LOC_SCREEN, LOC_BUFFER), GraphicsMode (MODE_8BPP), TilemapType (TILE_16_PIXEL ...)
Constants: LCD_WIDTH, LCD_HEIGHT.  Palette[256] (1555).
Rule: gfx_Xxx -> Xxx. Exceptions:
  gfx_Begin/End -> DrawBegin/DrawEnd;  gfx_ShiftLeft.. -> LCDShiftLeft..
  gfx_Sprite*, gfx_TransparentSprite*, gfx_Scaled*Sprite_NoClip -> DrawSprite*, DrawTransparentSprite*, DrawScaled*Sprite_NoClip
  gfx_Tilemap*, gfx_TransparentTilemap* -> DrawTilemap*, DrawTransparentTilemap*
Extras (all platforms): SwapPoint, Triangle, FillTriangle, RGBTo255,
  setup_xlibc_palette, setup_default_palette, setup_grayscale_palette, setup_web_palette.

## files.h
OpenFile, CloseFile, ReadFile, WriteFile, DeleteFile, FileExists, PutFileChar, GetFileChar,
SeekFile, TellFile, RewindFile, FileSize, GetFileDataPtr.

## random.h
random(), srandom() (provided by libc / tice.h; defined on Windows), uint24_t, int24_t,
RandomRange(lo,hi) inclusive, RandomChance(percent), RandomFloat() [0,1),
HashU32, Hash2D, ValueNoise2D(x,y,seed) 0..1, PerlinNoise2D(x,y,seed) ~-1..1, FractalNoise2D(x,y,seed,octaves).

Note: graphics.h / files.h cannot be used together with <windows.h> (Rectangle, OpenFile, ReadFile, ... clash).
