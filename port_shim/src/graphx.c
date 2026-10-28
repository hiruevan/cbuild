#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "graphx.h"
#include "ce_internal.h"

#define W GFX_LCD_WIDTH
#define H GFX_LCD_HEIGHT

#ifndef CE_WINDOW_TITLE
#define CE_WINDOW_TITLE "CE Game (desktop)"
#endif


static const uint8_t font8x8[95][8] = {
    {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00}, {0x18,0x3C,0x3C,0x18,0x18,0x00,0x18,0x00},
    {0x36,0x36,0x00,0x00,0x00,0x00,0x00,0x00}, {0x36,0x36,0x7F,0x36,0x7F,0x36,0x36,0x00},
    {0x0C,0x3E,0x03,0x1E,0x30,0x1F,0x0C,0x00}, {0x00,0x63,0x33,0x18,0x0C,0x66,0x63,0x00},
    {0x1C,0x36,0x1C,0x6E,0x3B,0x33,0x6E,0x00}, {0x06,0x06,0x03,0x00,0x00,0x00,0x00,0x00},
    {0x18,0x0C,0x06,0x06,0x06,0x0C,0x18,0x00}, {0x06,0x0C,0x18,0x18,0x18,0x0C,0x06,0x00},
    {0x00,0x66,0x3C,0xFF,0x3C,0x66,0x00,0x00}, {0x00,0x0C,0x0C,0x3F,0x0C,0x0C,0x00,0x00},
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x06}, {0x00,0x00,0x00,0x3F,0x00,0x00,0x00,0x00},
    {0x00,0x00,0x00,0x00,0x00,0x0C,0x0C,0x00}, {0x60,0x30,0x18,0x0C,0x06,0x03,0x01,0x00},
    {0x3E,0x63,0x73,0x7B,0x6F,0x67,0x3E,0x00}, {0x0C,0x0E,0x0C,0x0C,0x0C,0x0C,0x3F,0x00},
    {0x1E,0x33,0x30,0x1C,0x06,0x33,0x3F,0x00}, {0x1E,0x33,0x30,0x1C,0x30,0x33,0x1E,0x00},
    {0x38,0x3C,0x36,0x33,0x7F,0x30,0x78,0x00}, {0x3F,0x03,0x1F,0x30,0x30,0x33,0x1E,0x00},
    {0x1C,0x06,0x03,0x1F,0x33,0x33,0x1E,0x00}, {0x3F,0x33,0x30,0x18,0x0C,0x0C,0x0C,0x00},
    {0x1E,0x33,0x33,0x1E,0x33,0x33,0x1E,0x00}, {0x1E,0x33,0x33,0x3E,0x30,0x18,0x0E,0x00},
    {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x00}, {0x00,0x0C,0x0C,0x00,0x00,0x0C,0x0C,0x06},
    {0x18,0x0C,0x06,0x03,0x06,0x0C,0x18,0x00}, {0x00,0x00,0x3F,0x00,0x00,0x3F,0x00,0x00},
    {0x06,0x0C,0x18,0x30,0x18,0x0C,0x06,0x00}, {0x1E,0x33,0x30,0x18,0x0C,0x00,0x0C,0x00},
    {0x3E,0x63,0x7B,0x7B,0x7B,0x03,0x1E,0x00}, {0x0C,0x1E,0x33,0x33,0x3F,0x33,0x33,0x00},
    {0x3F,0x66,0x66,0x3E,0x66,0x66,0x3F,0x00}, {0x3C,0x66,0x03,0x03,0x03,0x66,0x3C,0x00},
    {0x1F,0x36,0x66,0x66,0x66,0x36,0x1F,0x00}, {0x7F,0x46,0x16,0x1E,0x16,0x46,0x7F,0x00},
    {0x7F,0x46,0x16,0x1E,0x16,0x06,0x0F,0x00}, {0x3C,0x66,0x03,0x03,0x73,0x66,0x7C,0x00},
    {0x33,0x33,0x33,0x3F,0x33,0x33,0x33,0x00}, {0x1E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00},
    {0x78,0x30,0x30,0x30,0x33,0x33,0x1E,0x00}, {0x67,0x66,0x36,0x1E,0x36,0x66,0x67,0x00},
    {0x0F,0x06,0x06,0x06,0x46,0x66,0x7F,0x00}, {0x63,0x77,0x7F,0x7F,0x6B,0x63,0x63,0x00},
    {0x63,0x67,0x6F,0x7B,0x73,0x63,0x63,0x00}, {0x1C,0x36,0x63,0x63,0x63,0x36,0x1C,0x00},
    {0x3F,0x66,0x66,0x3E,0x06,0x06,0x0F,0x00}, {0x1E,0x33,0x33,0x33,0x3B,0x1E,0x38,0x00},
    {0x3F,0x66,0x66,0x3E,0x36,0x66,0x67,0x00}, {0x1E,0x33,0x07,0x0E,0x38,0x33,0x1E,0x00},
    {0x3F,0x2D,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, {0x33,0x33,0x33,0x33,0x33,0x33,0x3F,0x00},
    {0x33,0x33,0x33,0x33,0x33,0x1E,0x0C,0x00}, {0x63,0x63,0x63,0x6B,0x7F,0x77,0x63,0x00},
    {0x63,0x63,0x36,0x1C,0x1C,0x36,0x63,0x00}, {0x33,0x33,0x33,0x1E,0x0C,0x0C,0x1E,0x00},
    {0x7F,0x63,0x31,0x18,0x4C,0x66,0x7F,0x00}, {0x1E,0x06,0x06,0x06,0x06,0x06,0x1E,0x00},
    {0x03,0x06,0x0C,0x18,0x30,0x60,0x40,0x00}, {0x1E,0x18,0x18,0x18,0x18,0x18,0x1E,0x00},
    {0x08,0x1C,0x36,0x63,0x00,0x00,0x00,0x00}, {0x00,0x00,0x00,0x00,0x00,0x00,0x00,0xFF},
    {0x0C,0x0C,0x18,0x00,0x00,0x00,0x00,0x00}, {0x00,0x00,0x1E,0x30,0x3E,0x33,0x6E,0x00},
    {0x07,0x06,0x06,0x3E,0x66,0x66,0x3B,0x00}, {0x00,0x00,0x1E,0x33,0x03,0x33,0x1E,0x00},
    {0x38,0x30,0x30,0x3E,0x33,0x33,0x6E,0x00}, {0x00,0x00,0x1E,0x33,0x3F,0x03,0x1E,0x00},
    {0x1C,0x36,0x06,0x0F,0x06,0x06,0x0F,0x00}, {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x1F},
    {0x07,0x06,0x36,0x6E,0x66,0x66,0x67,0x00}, {0x0C,0x00,0x0E,0x0C,0x0C,0x0C,0x1E,0x00},
    {0x30,0x00,0x30,0x30,0x30,0x33,0x33,0x1E}, {0x07,0x06,0x66,0x36,0x1E,0x36,0x67,0x00},
    {0x0E,0x0C,0x0C,0x0C,0x0C,0x0C,0x1E,0x00}, {0x00,0x00,0x33,0x7F,0x7F,0x6B,0x63,0x00},
    {0x00,0x00,0x1F,0x33,0x33,0x33,0x33,0x00}, {0x00,0x00,0x1E,0x33,0x33,0x33,0x1E,0x00},
    {0x00,0x00,0x3B,0x66,0x66,0x3E,0x06,0x0F}, {0x00,0x00,0x6E,0x33,0x33,0x3E,0x30,0x78},
    {0x00,0x00,0x3B,0x6E,0x66,0x06,0x0F,0x00}, {0x00,0x00,0x3E,0x03,0x1E,0x30,0x1F,0x00},
    {0x08,0x0C,0x3E,0x0C,0x0C,0x2C,0x18,0x00}, {0x00,0x00,0x33,0x33,0x33,0x33,0x6E,0x00},
    {0x00,0x00,0x33,0x33,0x33,0x1E,0x0C,0x00}, {0x00,0x00,0x63,0x6B,0x7F,0x7F,0x36,0x00},
    {0x00,0x00,0x63,0x36,0x1C,0x36,0x63,0x00}, {0x00,0x00,0x33,0x33,0x33,0x3E,0x30,0x1F},
    {0x00,0x00,0x3F,0x19,0x0C,0x26,0x3F,0x00}, {0x38,0x0C,0x0C,0x07,0x0C,0x0C,0x38,0x00},
    {0x18,0x18,0x18,0x00,0x18,0x18,0x18,0x00}, {0x07,0x0C,0x0C,0x38,0x0C,0x0C,0x07,0x00},
    {0x6E,0x3B,0x00,0x00,0x00,0x00,0x00,0x00}
};

static SDL_Window   *window;
static SDL_Renderer *renderer;
static SDL_Texture  *texture;

static uint8_t  bufs[2][W * H];
static uint8_t *display_buf = bufs[0];
static uint8_t *draw_buf    = bufs[1];
uint16_t gfx_palette[256];

static uint8_t  color_idx = 0;
static uint8_t  transparent_idx = 0;
static int      clip_x0 = 0, clip_y0 = 0, clip_x1 = W, clip_y1 = H;

static int      text_x = 0, text_y = 0;
static uint8_t  text_fg = 0, text_bg = 255, text_trans = 255;
static uint8_t  text_sx = 1, text_sy = 1;

static uint32_t last_present = 0;

int ce_video_ready(void) { return window != NULL; }

static uint32_t from_1555(uint16_t v)
{
    unsigned r5 = (v >> 10) & 31, b5 = v & 31;
    unsigned g6 = (((v >> 5) & 31) << 1) | (v >> 15);
    unsigned r = (r5 << 3) | (r5 >> 2), g = (g6 << 2) | (g6 >> 4), b = (b5 << 3) | (b5 >> 2);
    return 0xFF000000u | (r << 16) | (g << 8) | b;
}

void gfx_SetDefaultPalette(gfx_mode_t mode)
{
    (void)mode;
    for (int i = 0; i < 256; i++) {
        unsigned r = (i >> 5) & 7, g = (i >> 2) & 7, b = i & 3;
        r = (r << 5) | (r << 2) | (r >> 1);
        g = (g << 5) | (g << 2) | (g >> 1);
        b = (b << 6) | (b << 4) | (b << 2) | b;
        gfx_palette[i] = gfx_RGBTo1555(r, g, b);
    }
}

void gfx_SetPalette(const void *palette, uint24_t size, uint8_t offset)
{
    const uint8_t *p = (const uint8_t *)palette;
    unsigned count = size / 2;
    for (unsigned i = 0; i < count && (offset + i) < 256; i++) {
        gfx_palette[offset + i] = (uint16_t)(p[2 * i] | (p[2 * i + 1] << 8));
    }
}

static void present(void)
{
    if (!window) return;
    uint32_t palette_argb[256];
    for (int i = 0; i < 256; i++) palette_argb[i] = from_1555(gfx_palette[i]);

    void *pixels; int pitch;
    if (SDL_LockTexture(texture, NULL, &pixels, &pitch) == 0) {
        for (int y = 0; y < H; y++) {
            uint32_t *row = (uint32_t *)((uint8_t *)pixels + y * pitch);
            const uint8_t *src = display_buf + y * W;
            for (int x = 0; x < W; x++) row[x] = palette_argb[src[x]];
        }
        SDL_UnlockTexture(texture);
    }
    SDL_RenderClear(renderer);
    SDL_RenderCopy(renderer, texture, NULL, NULL);
    SDL_RenderPresent(renderer);
    last_present = SDL_GetTicks();
}

void ce_present_if_due(void)
{
    if (window && SDL_GetTicks() - last_present >= 16) present();
}

static void throttle_and_present(void)
{
    uint32_t now = SDL_GetTicks();
    if (now - last_present < 16) SDL_Delay(16 - (now - last_present));
    present();
}

void gfx_Begin(void)
{
    SDL_SetMainReady();
    if (SDL_Init(SDL_INIT_VIDEO) != 0) {
        fprintf(stderr, "SDL_Init failed: %s\n", SDL_GetError());
        exit(1);
    }
    SDL_SetHint(SDL_HINT_RENDER_SCALE_QUALITY, "0");
    window = SDL_CreateWindow(CE_WINDOW_TITLE, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
                              W * 2, H * 2, SDL_WINDOW_RESIZABLE);
    if (!window) { fprintf(stderr, "Window failed: %s\n", SDL_GetError()); exit(1); }
    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED);
    if (!renderer) renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    if (!renderer) { fprintf(stderr, "Renderer failed: %s\n", SDL_GetError()); exit(1); }
    SDL_RenderSetLogicalSize(renderer, W, H);
    SDL_RenderSetIntegerScale(renderer, SDL_TRUE);
    texture = SDL_CreateTexture(renderer, SDL_PIXELFORMAT_ARGB8888, SDL_TEXTUREACCESS_STREAMING, W, H);

    gfx_SetDefaultPalette(gfx_8bpp);
    memset(bufs, 0, sizeof bufs);
    display_buf = bufs[0];
    draw_buf = bufs[1];
    color_idx = 0; transparent_idx = 0;
    clip_x0 = 0; clip_y0 = 0; clip_x1 = W; clip_y1 = H;
    text_x = text_y = 0; text_fg = 0; text_bg = 255; text_trans = 255; text_sx = text_sy = 1;
    present();
}

void gfx_End(void)
{
    if (texture)  SDL_DestroyTexture(texture);
    if (renderer) SDL_DestroyRenderer(renderer);
    if (window)   SDL_DestroyWindow(window);
    texture = NULL; renderer = NULL; window = NULL;
    SDL_Quit();
}

static uint8_t *other_buf(void) { return display_buf == bufs[0] ? bufs[1] : bufs[0]; }

void gfx_SetDraw(uint8_t location) { draw_buf = (location == gfx_screen) ? display_buf : other_buf(); }
uint8_t gfx_GetDraw(void) { return draw_buf == display_buf ? gfx_screen : gfx_buffer; }
void gfx_SetDrawScreen(void) { gfx_SetDraw(gfx_screen); }
void gfx_SetDrawBuffer(void) { gfx_SetDraw(gfx_buffer); }

void gfx_SwapDraw(void)
{
    uint8_t *old_display = display_buf;
    display_buf = draw_buf;
    draw_buf = old_display;
    throttle_and_present();
}

void gfx_Wait(void) { throttle_and_present(); }

void gfx_Blit(gfx_location_t src)
{
    if (src == gfx_buffer) memcpy(display_buf, other_buf(), W * H);
    else                   memcpy(other_buf(), display_buf, W * H);
    throttle_and_present();
}
void gfx_BlitBuffer(void) { gfx_Blit(gfx_buffer); }
void gfx_BlitScreen(void) { gfx_Blit(gfx_screen); }

uint8_t gfx_SetColor(uint8_t i) { uint8_t o = color_idx; color_idx = i; return o; }
uint8_t gfx_SetTransparentColor(uint8_t i) { uint8_t o = transparent_idx; transparent_idx = i; return o; }

void gfx_SetClipRegion(int xmin, int ymin, int xmax, int ymax)
{
    clip_x0 = xmin < 0 ? 0 : xmin;
    clip_y0 = ymin < 0 ? 0 : ymin;
    clip_x1 = xmax > W ? W : xmax;
    clip_y1 = ymax > H ? H : ymax;
}

void gfx_FillScreen(uint8_t c) { memset(draw_buf, c, W * H); }
void gfx_ZeroScreen(void) { memset(draw_buf, 0, W * H); }

static inline void put(int x, int y, uint8_t c)
{
    if (x >= clip_x0 && x < clip_x1 && y >= clip_y0 && y < clip_y1) draw_buf[y * W + x] = c;
}

void gfx_SetPixel(uint24_t x, uint8_t y) { put((int)x, y, color_idx); }
uint8_t gfx_GetPixel(uint24_t x, uint8_t y)
{
    return (x < W && y < H) ? draw_buf[y * W + x] : 0;
}

void gfx_HorizLine(int x, int y, int len)
{
    if (len <= 0 || y < clip_y0 || y >= clip_y1) return;
    int x0 = x < clip_x0 ? clip_x0 : x, x1 = (x + len) > clip_x1 ? clip_x1 : (x + len);
    if (x1 > x0) memset(draw_buf + y * W + x0, color_idx, x1 - x0);
}
void gfx_HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { gfx_HorizLine((int)x, y, (int)len); }

void gfx_VertLine(int x, int y, int len)
{
    if (len <= 0 || x < clip_x0 || x >= clip_x1) return;
    int y0 = y < clip_y0 ? clip_y0 : y, y1 = (y + len) > clip_y1 ? clip_y1 : (y + len);
    for (int j = y0; j < y1; j++) draw_buf[j * W + x] = color_idx;
}
void gfx_VertLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { gfx_VertLine((int)x, y, (int)len); }

void gfx_Line(int x0, int y0, int x1, int y1)
{
    int dx = abs(x1 - x0), sx = x0 < x1 ? 1 : -1;
    int dy = -abs(y1 - y0), sy = y0 < y1 ? 1 : -1;
    int err = dx + dy;
    for (;;) {
        put(x0, y0, color_idx);
        if (x0 == x1 && y0 == y1) break;
        int e2 = 2 * err;
        if (e2 >= dy) { err += dy; x0 += sx; }
        if (e2 <= dx) { err += dx; y0 += sy; }
    }
}
void gfx_Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1) { gfx_Line((int)x0, y0, (int)x1, y1); }

void gfx_FillRectangle(int x, int y, int w, int h)
{
    for (int j = 0; j < h; j++) gfx_HorizLine(x, y + j, w);
}
void gfx_FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { gfx_FillRectangle((int)x, y, (int)w, h); }

void gfx_Rectangle(int x, int y, int w, int h)
{
    if (w <= 0 || h <= 0) return;
    gfx_HorizLine(x, y, w);
    gfx_HorizLine(x, y + h - 1, w);
    gfx_VertLine(x, y, h);
    gfx_VertLine(x + w - 1, y, h);
}
void gfx_Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { gfx_Rectangle((int)x, y, (int)w, h); }

void gfx_Circle(int cx, int cy, uint24_t radius)
{
    int x = (int)radius, y = 0, err = 1 - x;
    while (x >= y) {
        put(cx + x, cy + y, color_idx); put(cx + y, cy + x, color_idx);
        put(cx - y, cy + x, color_idx); put(cx - x, cy + y, color_idx);
        put(cx - x, cy - y, color_idx); put(cx - y, cy - x, color_idx);
        put(cx + y, cy - x, color_idx); put(cx + x, cy - y, color_idx);
        y++;
        if (err < 0) err += 2 * y + 1;
        else { x--; err += 2 * (y - x) + 1; }
    }
}
void gfx_Circle_NoClip(uint24_t x, uint8_t y, uint8_t r) { gfx_Circle((int)x, y, r); }

void gfx_FillCircle(int cx, int cy, uint24_t radius)
{
    int r = (int)radius;
    for (int dy = -r; dy <= r; dy++) {
        int dx = (int)floor(sqrt((double)(r * r - dy * dy)) + 0.5);
        gfx_HorizLine(cx - dx, cy + dy, 2 * dx + 1);
    }
}
void gfx_FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t r) { gfx_FillCircle((int)x, y, r); }

gfx_sprite_t *gfx_internal_init_sprite(void *mem, uint8_t w, uint8_t h)
{
    gfx_sprite_t *s = (gfx_sprite_t *)mem;
    if (s) { s->width = w; s->height = h; }
    return s;
}

gfx_sprite_t *gfx_MallocSprite(uint8_t w, uint8_t h)
{
    return gfx_internal_init_sprite(malloc(2 + (size_t)w * h), w, h);
}

void gfx_ShiftLeft(uint24_t n)
{
    if (n == 0 || n >= W) return;
    for (int y = 0; y < H; y++) memmove(draw_buf + y * W, draw_buf + y * W + n, W - n);
}
void gfx_ShiftRight(uint24_t n)
{
    if (n == 0 || n >= W) return;
    for (int y = 0; y < H; y++) memmove(draw_buf + y * W + n, draw_buf + y * W, W - n);
}
void gfx_ShiftUp(uint24_t n)
{
    if (n == 0 || n >= H) return;
    memmove(draw_buf, draw_buf + n * W, (size_t)(H - n) * W);
}
void gfx_ShiftDown(uint24_t n)
{
    if (n == 0 || n >= H) return;
    memmove(draw_buf + n * W, draw_buf, (size_t)(H - n) * W);
}

static void blit_sprite(const gfx_sprite_t *s, int x, int y, int sw, int sh, int transparent)
{
    if (!s || sw < 1 || sh < 1) return;
    for (int j = 0; j < s->height; j++) {
        for (int i = 0; i < s->width; i++) {
            uint8_t c = s->data[j * s->width + i];
            if (transparent && c == transparent_idx) continue;
            for (int b = 0; b < sh; b++)
                for (int a = 0; a < sw; a++)
                    put(x + i * sw + a, y + j * sh + b, c);
        }
    }
}

void gfx_Sprite(const gfx_sprite_t *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 0); }
void gfx_Sprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 0); }
void gfx_TransparentSprite(const gfx_sprite_t *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 1); }
void gfx_TransparentSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 1); }
void gfx_ScaledSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 0); }
void gfx_ScaledTransparentSprite_NoClip(const gfx_sprite_t *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 1); }

gfx_sprite_t *gfx_GetSprite(gfx_sprite_t *out, int x, int y)
{
    for (int j = 0; j < out->height; j++)
        for (int i = 0; i < out->width; i++) {
            int px = x + i, py = y + j;
            out->data[j * out->width + i] =
                (px >= 0 && px < W && py >= 0 && py < H) ? draw_buf[py * W + px] : 0;
        }
    return out;
}

gfx_sprite_t *gfx_FlipSpriteY(const gfx_sprite_t *in, gfx_sprite_t *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[j * in->width + (in->width - 1 - i)] = in->data[j * in->width + i];
    return out;
}

gfx_sprite_t *gfx_FlipSpriteX(const gfx_sprite_t *in, gfx_sprite_t *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[(in->height - 1 - j) * in->width + i] = in->data[j * in->width + i];
    return out;
}

static void draw_tilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo, int transparent)
{
    unsigned tw = t->tile_width ? t->tile_width : 1, th = t->tile_height ? t->tile_height : 1;
    unsigned col0 = xo / tw, row0 = yo / th;
    int px0 = (int)t->x_loc - (int)(xo % tw), py0 = (int)t->y_loc - (int)(yo % th);
    for (unsigned r = 0; r < t->draw_height; r++) {
        for (unsigned c = 0; c < t->draw_width; c++) {
            unsigned mc = col0 + c, mr = row0 + r;
            if (mc >= t->width || mr >= t->height) continue;
            const gfx_sprite_t *s = t->tiles[t->map[mr * t->width + mc]];
            blit_sprite(s, px0 + (int)(c * tw), py0 + (int)(r * th), 1, 1, transparent);
        }
    }
}
void gfx_Tilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void gfx_Tilemap_NoClip(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void gfx_TransparentTilemap(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }
void gfx_TransparentTilemap_NoClip(const gfx_tilemap_t *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }

uint8_t gfx_SetTextFGColor(uint8_t c) { uint8_t o = text_fg; text_fg = c; return o; }
uint8_t gfx_SetTextBGColor(uint8_t c) { uint8_t o = text_bg; text_bg = c; return o; }
uint8_t gfx_SetTextTransparentColor(uint8_t c) { uint8_t o = text_trans; text_trans = c; return o; }
void gfx_SetTextScale(uint8_t ws, uint8_t hs) { text_sx = ws ? ws : 1; text_sy = hs ? hs : 1; }
void gfx_SetTextXY(int x, int y) { text_x = x; text_y = y; }
int gfx_GetTextX(void) { return text_x; }
int gfx_GetTextY(void) { return text_y; }
uint24_t gfx_GetCharWidth(const char c) { (void)c; return 8u * text_sx; }
uint24_t gfx_GetStringWidth(const char *s) { return (uint24_t)strlen(s) * 8u * text_sx; }

void gfx_PrintChar(const char ch)
{
    unsigned idx = (unsigned char)ch;
    if (idx < 32 || idx > 126) idx = '?';
    const uint8_t *g = font8x8[idx - 32];

    uint8_t saved = color_idx;
    if (text_bg != text_trans) {
        color_idx = text_bg;
        gfx_FillRectangle(text_x, text_y, 8 * text_sx, 8 * text_sy);
    }
    color_idx = text_fg;
    for (int row = 0; row < 8; row++)
        for (int col = 0; col < 8; col++)
            if ((g[row] >> col) & 1)
                gfx_FillRectangle(text_x + col * text_sx, text_y + row * text_sy, text_sx, text_sy);
    color_idx = saved;
    text_x += 8 * text_sx;
}

void gfx_PrintString(const char *s) { while (*s) gfx_PrintChar(*s++); }

void gfx_PrintStringXY(const char *s, int x, int y)
{
    gfx_SetTextXY(x, y);
    gfx_PrintString(s);
}

void gfx_PrintInt(int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*d", (int)length, n);
    gfx_PrintString(buf);
}

void gfx_PrintUInt(unsigned int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*u", (int)length, n);
    gfx_PrintString(buf);
}
