#ifndef CE_SHIM_GRAPHICS_H
#define CE_SHIM_GRAPHICS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <random.h>

#if defined(_WIN32) && defined(_WINDOWS_)
#error "graphics.h defines Rectangle(), Line() etc., which clash with <windows.h>. Do not include <windows.h> in code that uses graphics.h."
#endif

#ifdef __cplusplus
extern "C" {
#endif

#define LCD_WIDTH  320
#define LCD_HEIGHT 240

typedef struct Sprite {
    uint8_t width;
    uint8_t height;
    uint8_t data[];
} Sprite;

typedef struct Tilemap {
    uint8_t *map;
    Sprite **tiles;
    uint8_t tile_height;
    uint8_t tile_width;
    uint8_t draw_height;
    uint8_t draw_width;
    uint8_t type_width;
    uint8_t type_height;
    uint8_t height;
    uint8_t width;
    uint8_t y_loc;
    uint8_t x_loc;
} Tilemap;

typedef enum { LOC_SCREEN = 0, LOC_BUFFER = 1 } DrawLocation;

typedef enum {
    TILE_NO_POW2 = 0,
    TILE_2_PIXEL,
    TILE_4_PIXEL,
    TILE_8_PIXEL,
    TILE_16_PIXEL,
    TILE_32_PIXEL,
    TILE_64_PIXEL,
    TILE_128_PIXEL
} TilemapType;

typedef enum { MODE_8BPP = 0x27 } GraphicsMode;

#define RGBTo1555(r, g, b) \
    ((uint16_t)((((uint16_t)(r) & 0xF8) << 7) | (((uint16_t)(g) & 0xF8) << 2) | \
                (((uint16_t)(b) & 0xF8) >> 3) | (((uint16_t)(g) & 0x04) << 13)))

#define UninitedSprite(name, w, h) \
    uint8_t name##_data[2 + (w) * (h)]; \
    Sprite *name = (Sprite *)name##_data
#define TempSprite(name, w, h) UninitedSprite(name, w, h)
#define AllocSprite(w, h, malloc_routine) \
    ((Sprite *)internal_init_sprite((malloc_routine)(2 + (size_t)(w) * (h)), (w), (h)))

Sprite *internal_init_sprite(void *mem, uint8_t w, uint8_t h);
Sprite *MallocSprite(uint8_t width, uint8_t height);

extern uint16_t Palette[256];

void LCDShiftLeft(uint24_t pixels);
void LCDShiftRight(uint24_t pixels);
void LCDShiftUp(uint24_t pixels);
void LCDShiftDown(uint24_t pixels);

void DrawBegin(void);
void DrawEnd(void);
void SetPalette(const void *palette, uint24_t size, uint8_t offset);
void SetDefaultPalette(GraphicsMode mode);

void SetDraw(uint8_t location);
uint8_t GetDraw(void);
void SetDrawScreen(void);
void SetDrawBuffer(void);
void SwapDraw(void);
void Wait(void);
void Blit(DrawLocation src);
void BlitBuffer(void);
void BlitScreen(void);

uint8_t SetColor(uint8_t index);
uint8_t SetTransparentColor(uint8_t index);
void SetClipRegion(int xmin, int ymin, int xmax, int ymax);
void FillScreen(uint8_t color);
void ZeroScreen(void);

void SetPixel(uint24_t x, uint8_t y);
uint8_t GetPixel(uint24_t x, uint8_t y);
void Line(int x0, int y0, int x1, int y1);
void Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1);
void HorizLine(int x, int y, int length);
void HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void VertLine(int x, int y, int length);
void VertLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void Rectangle(int x, int y, int width, int height);
void Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void FillRectangle(int x, int y, int width, int height);
void FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void Circle(int x, int y, uint24_t radius);
void FillCircle(int x, int y, uint24_t radius);
void Circle_NoClip(uint24_t x, uint8_t y, uint8_t radius);
void FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t radius);

void DrawSprite(const Sprite *sprite, int x, int y);
void DrawSprite_NoClip(const Sprite *sprite, uint24_t x, uint8_t y);
void DrawTransparentSprite(const Sprite *sprite, int x, int y);
void DrawTransparentSprite_NoClip(const Sprite *sprite, uint24_t x, uint8_t y);
void DrawScaledSprite_NoClip(const Sprite *sprite, uint24_t x, uint8_t y,
                             uint8_t width_scale, uint8_t height_scale);
void DrawScaledTransparentSprite_NoClip(const Sprite *sprite, uint24_t x, uint8_t y,
                                        uint8_t width_scale, uint8_t height_scale);
Sprite *GetSprite(Sprite *sprite_buffer, int x, int y);
Sprite *FlipSpriteY(const Sprite *sprite_in, Sprite *sprite_out);
Sprite *FlipSpriteX(const Sprite *sprite_in, Sprite *sprite_out);

void DrawTilemap(const Tilemap *tilemap, uint24_t x_offset, uint24_t y_offset);
void DrawTilemap_NoClip(const Tilemap *tilemap, uint24_t x_offset, uint24_t y_offset);
void DrawTransparentTilemap(const Tilemap *tilemap, uint24_t x_offset, uint24_t y_offset);
void DrawTransparentTilemap_NoClip(const Tilemap *tilemap, uint24_t x_offset, uint24_t y_offset);

void PrintChar(const char c);
void PrintInt(int n, uint8_t length);
void PrintUInt(unsigned int n, uint8_t length);
void PrintString(const char *string);
void PrintStringXY(const char *string, int x, int y);
void SetTextXY(int x, int y);
int GetTextX(void);
int GetTextY(void);
uint8_t SetTextFGColor(uint8_t color);
uint8_t SetTextBGColor(uint8_t color);
uint8_t SetTextTransparentColor(uint8_t color);
void SetTextScale(uint8_t width_scale, uint8_t height_scale);
uint24_t GetStringWidth(const char *string);
uint24_t GetCharWidth(const char c);

/* Shared helpers: Point, triangles, palettes, RGBTo255 (same file on every platform) */
#include "../common/graphics_common.h"

#ifdef __cplusplus
}
#endif

#endif
