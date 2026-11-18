/*
 * Calculator graphics.h: the shared graphics API implemented on top of CEdev's
 * graphx library. Everything is a thin alias, so there is no runtime cost and
 * no extra source file to compile.
 */
#ifndef CE_SHIM_CALC_GRAPHICS_H
#define CE_SHIM_CALC_GRAPHICS_H

#include <graphx.h>
#include <random.h>      /* shim/calc/random.h -> tice.h */

/* ---- types and constants ---- */
typedef gfx_sprite_t       Sprite;
typedef gfx_tilemap_t      Tilemap;
typedef gfx_location_t     DrawLocation;
typedef gfx_tilemap_type_t TilemapType;
typedef gfx_mode_t         GraphicsMode;

#define LCD_WIDTH   GFX_LCD_WIDTH
#define LCD_HEIGHT  GFX_LCD_HEIGHT

#define LOC_SCREEN  gfx_screen
#define LOC_BUFFER  gfx_buffer
#define MODE_8BPP   gfx_8bpp

#define TILE_NO_POW2   gfx_tile_no_pow2
#define TILE_2_PIXEL   gfx_tile_2_pixel
#define TILE_4_PIXEL   gfx_tile_4_pixel
#define TILE_8_PIXEL   gfx_tile_8_pixel
#define TILE_16_PIXEL  gfx_tile_16_pixel
#define TILE_32_PIXEL  gfx_tile_32_pixel
#define TILE_64_PIXEL  gfx_tile_64_pixel
#define TILE_128_PIXEL gfx_tile_128_pixel

#define Palette gfx_palette

#define RGBTo1555(r, g, b)               gfx_RGBTo1555(r, g, b)
#define UninitedSprite(name, w, h)       gfx_UninitedSprite(name, w, h)
#define TempSprite(name, w, h)           gfx_TempSprite(name, w, h)
#define AllocSprite(w, h, malloc_routine) gfx_AllocSprite(w, h, malloc_routine)

/* ---- functions ---- */
#define MallocSprite(...) gfx_MallocSprite(__VA_ARGS__)
#define LCDShiftLeft(...) gfx_ShiftLeft(__VA_ARGS__)
#define LCDShiftRight(...) gfx_ShiftRight(__VA_ARGS__)
#define LCDShiftUp(...) gfx_ShiftUp(__VA_ARGS__)
#define LCDShiftDown(...) gfx_ShiftDown(__VA_ARGS__)
#define DrawBegin(...) gfx_Begin(__VA_ARGS__)
#define DrawEnd(...) gfx_End(__VA_ARGS__)
#define SetPalette(...) gfx_SetPalette(__VA_ARGS__)
#define SetDefaultPalette(...) gfx_SetDefaultPalette(__VA_ARGS__)
#define SetDraw(...) gfx_SetDraw(__VA_ARGS__)
#define GetDraw(...) gfx_GetDraw(__VA_ARGS__)
#define SetDrawScreen(...) gfx_SetDrawScreen(__VA_ARGS__)
#define SetDrawBuffer(...) gfx_SetDrawBuffer(__VA_ARGS__)
#define SwapDraw(...) gfx_SwapDraw(__VA_ARGS__)
#define Wait(...) gfx_Wait(__VA_ARGS__)
#define Blit(...) gfx_Blit(__VA_ARGS__)
#define BlitBuffer(...) gfx_BlitBuffer(__VA_ARGS__)
#define BlitScreen(...) gfx_BlitScreen(__VA_ARGS__)
#define SetColor(...) gfx_SetColor(__VA_ARGS__)
#define SetTransparentColor(...) gfx_SetTransparentColor(__VA_ARGS__)
#define SetClipRegion(...) gfx_SetClipRegion(__VA_ARGS__)
#define FillScreen(...) gfx_FillScreen(__VA_ARGS__)
#define ZeroScreen(...) gfx_ZeroScreen(__VA_ARGS__)
#define SetPixel(...) gfx_SetPixel(__VA_ARGS__)
#define GetPixel(...) gfx_GetPixel(__VA_ARGS__)
#define Line(...) gfx_Line(__VA_ARGS__)
#define Line_NoClip(...) gfx_Line_NoClip(__VA_ARGS__)
#define HorizLine(...) gfx_HorizLine(__VA_ARGS__)
#define HorizLine_NoClip(...) gfx_HorizLine_NoClip(__VA_ARGS__)
#define VertLine(...) gfx_VertLine(__VA_ARGS__)
#define VertLine_NoClip(...) gfx_VertLine_NoClip(__VA_ARGS__)
#define Rectangle(...) gfx_Rectangle(__VA_ARGS__)
#define Rectangle_NoClip(...) gfx_Rectangle_NoClip(__VA_ARGS__)
#define FillRectangle(...) gfx_FillRectangle(__VA_ARGS__)
#define FillRectangle_NoClip(...) gfx_FillRectangle_NoClip(__VA_ARGS__)
#define Circle(...) gfx_Circle(__VA_ARGS__)
#define FillCircle(...) gfx_FillCircle(__VA_ARGS__)
#define Circle_NoClip(...) gfx_Circle_NoClip(__VA_ARGS__)
#define FillCircle_NoClip(...) gfx_FillCircle_NoClip(__VA_ARGS__)
#define DrawSprite(...) gfx_Sprite(__VA_ARGS__)
#define DrawSprite_NoClip(...) gfx_Sprite_NoClip(__VA_ARGS__)
#define DrawTransparentSprite(...) gfx_TransparentSprite(__VA_ARGS__)
#define DrawTransparentSprite_NoClip(...) gfx_TransparentSprite_NoClip(__VA_ARGS__)
#define DrawScaledSprite_NoClip(...) gfx_ScaledSprite_NoClip(__VA_ARGS__)
#define DrawScaledTransparentSprite_NoClip(...) gfx_ScaledTransparentSprite_NoClip(__VA_ARGS__)
#define GetSprite(...) gfx_GetSprite(__VA_ARGS__)
#define FlipSpriteY(...) gfx_FlipSpriteY(__VA_ARGS__)
#define FlipSpriteX(...) gfx_FlipSpriteX(__VA_ARGS__)
#define DrawTilemap(...) gfx_Tilemap(__VA_ARGS__)
#define DrawTilemap_NoClip(...) gfx_Tilemap_NoClip(__VA_ARGS__)
#define DrawTransparentTilemap(...) gfx_TransparentTilemap(__VA_ARGS__)
#define DrawTransparentTilemap_NoClip(...) gfx_TransparentTilemap_NoClip(__VA_ARGS__)
#define PrintChar(...) gfx_PrintChar(__VA_ARGS__)
#define PrintInt(...) gfx_PrintInt(__VA_ARGS__)
#define PrintUInt(...) gfx_PrintUInt(__VA_ARGS__)
#define PrintString(...) gfx_PrintString(__VA_ARGS__)
#define PrintStringXY(...) gfx_PrintStringXY(__VA_ARGS__)
#define SetTextXY(...) gfx_SetTextXY(__VA_ARGS__)
#define GetTextX(...) gfx_GetTextX(__VA_ARGS__)
#define GetTextY(...) gfx_GetTextY(__VA_ARGS__)
#define SetTextFGColor(...) gfx_SetTextFGColor(__VA_ARGS__)
#define SetTextBGColor(...) gfx_SetTextBGColor(__VA_ARGS__)
#define SetTextTransparentColor(...) gfx_SetTextTransparentColor(__VA_ARGS__)
#define SetTextScale(...) gfx_SetTextScale(__VA_ARGS__)
#define GetStringWidth(...) gfx_GetStringWidth(__VA_ARGS__)
#define GetCharWidth(...) gfx_GetCharWidth(__VA_ARGS__)

/* Shared helpers: Point, triangles, palettes, RGBTo255 */
#include "../common/graphics_common.h"

#endif
