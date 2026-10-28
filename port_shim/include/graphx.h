#ifndef CE_SHIM_GRAPHX_H
#define CE_SHIM_GRAPHX_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

#define GFX_LCD_WIDTH  320
#define GFX_LCD_HEIGHT 240

typedef struct gfx_sprite_t {
    uint8_t width;
    uint8_t height;
    uint8_t data[];
} gfx_sprite_t;

typedef struct gfx_tilemap_t {
    uint8_t *map;
    gfx_sprite_t **tiles;
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
} gfx_tilemap_t;

typedef enum { gfx_screen = 0, gfx_buffer = 1 } gfx_location_t;

typedef enum {
    gfx_tile_no_pow2 = 0,
    gfx_tile_2_pixel,
    gfx_tile_4_pixel,
    gfx_tile_8_pixel,
    gfx_tile_16_pixel,
    gfx_tile_32_pixel,
    gfx_tile_64_pixel,
    gfx_tile_128_pixel
} gfx_tilemap_type_t;

typedef enum { gfx_8bpp = 0x27 } gfx_mode_t;

#define gfx_RGBTo1555(r, g, b) \
    ((uint16_t)((((uint16_t)(r) & 0xF8) << 7) | (((uint16_t)(g) & 0xF8) << 2) | \
                (((uint16_t)(b) & 0xF8) >> 3) | (((uint16_t)(g) & 0x04) << 13)))

#define gfx_UninitedSprite(name, w, h) \
    uint8_t name##_data[2 + (w) * (h)]; \
    gfx_sprite_t *name = (gfx_sprite_t *)name##_data
#define gfx_TempSprite(name, w, h) gfx_UninitedSprite(name, w, h)
#define gfx_AllocSprite(w, h, malloc_routine) \
    ((gfx_sprite_t *)gfx_internal_init_sprite((malloc_routine)(2 + (size_t)(w) * (h)), (w), (h)))

gfx_sprite_t *gfx_internal_init_sprite(void *mem, uint8_t w, uint8_t h);
gfx_sprite_t *gfx_MallocSprite(uint8_t width, uint8_t height);

extern uint16_t gfx_palette[256];

void gfx_ShiftLeft(uint24_t pixels);
void gfx_ShiftRight(uint24_t pixels);
void gfx_ShiftUp(uint24_t pixels);
void gfx_ShiftDown(uint24_t pixels);

void gfx_Begin(void);
void gfx_End(void);
void gfx_SetPalette(const void *palette, uint24_t size, uint8_t offset);
void gfx_SetDefaultPalette(gfx_mode_t mode);

void gfx_SetDraw(uint8_t location);
uint8_t gfx_GetDraw(void);
void gfx_SetDrawScreen(void);
void gfx_SetDrawBuffer(void);
void gfx_SwapDraw(void);
void gfx_Wait(void);
void gfx_Blit(gfx_location_t src);
void gfx_BlitBuffer(void);
void gfx_BlitScreen(void);

uint8_t gfx_SetColor(uint8_t index);
uint8_t gfx_SetTransparentColor(uint8_t index);
void gfx_SetClipRegion(int xmin, int ymin, int xmax, int ymax);
void gfx_FillScreen(uint8_t color);
void gfx_ZeroScreen(void);

void gfx_SetPixel(uint24_t x, uint8_t y);
uint8_t gfx_GetPixel(uint24_t x, uint8_t y);
void gfx_Line(int x0, int y0, int x1, int y1);
void gfx_Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1);
void gfx_HorizLine(int x, int y, int length);
void gfx_HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void gfx_VertLine(int x, int y, int length);
void gfx_VertLine_NoClip(uint24_t x, uint8_t y, uint24_t length);
void gfx_Rectangle(int x, int y, int width, int height);
void gfx_Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void gfx_FillRectangle(int x, int y, int width, int height);
void gfx_FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t width, uint8_t height);
void gfx_Circle(int x, int y, uint24_t radius);
void gfx_FillCircle(int x, int y, uint24_t radius);
void gfx_Circle_NoClip(uint24_t x, uint8_t y, uint8_t radius);
void gfx_FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t radius);

void gfx_Sprite(const gfx_sprite_t *sprite, int x, int y);
void gfx_Sprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y);
void gfx_TransparentSprite(const gfx_sprite_t *sprite, int x, int y);
void gfx_TransparentSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y);
void gfx_ScaledSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y,
                             uint8_t width_scale, uint8_t height_scale);
void gfx_ScaledTransparentSprite_NoClip(const gfx_sprite_t *sprite, uint24_t x, uint8_t y,
                                        uint8_t width_scale, uint8_t height_scale);
gfx_sprite_t *gfx_GetSprite(gfx_sprite_t *sprite_buffer, int x, int y);
gfx_sprite_t *gfx_FlipSpriteY(const gfx_sprite_t *sprite_in, gfx_sprite_t *sprite_out);
gfx_sprite_t *gfx_FlipSpriteX(const gfx_sprite_t *sprite_in, gfx_sprite_t *sprite_out);

void gfx_Tilemap(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_Tilemap_NoClip(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_TransparentTilemap(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);
void gfx_TransparentTilemap_NoClip(const gfx_tilemap_t *tilemap, uint24_t x_offset, uint24_t y_offset);

void gfx_PrintChar(const char c);
void gfx_PrintInt(int n, uint8_t length);
void gfx_PrintUInt(unsigned int n, uint8_t length);
void gfx_PrintString(const char *string);
void gfx_PrintStringXY(const char *string, int x, int y);
void gfx_SetTextXY(int x, int y);
int gfx_GetTextX(void);
int gfx_GetTextY(void);
uint8_t gfx_SetTextFGColor(uint8_t color);
uint8_t gfx_SetTextBGColor(uint8_t color);
uint8_t gfx_SetTextTransparentColor(uint8_t color);
void gfx_SetTextScale(uint8_t width_scale, uint8_t height_scale);
uint24_t gfx_GetStringWidth(const char *string);
uint24_t gfx_GetCharWidth(const char c);

#ifdef __cplusplus
}
#endif

#endif
