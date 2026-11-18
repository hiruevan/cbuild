/*
 * GameCube graphics shim.
 *
 * Rendering is the same software renderer used by desk_shim: everything is
 * drawn into 8-bit, palette-indexed 320x240 buffers, so game code behaves the
 * same on every target. Only presentation differs: the indexed buffer is
 * converted through the palette into an RGB565 GX texture, drawn as a
 * full-screen quad into the EFB, and copied to the XFB.
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <malloc.h>
#include <ogc/video.h>
#include <ogc/system.h>
#include <ogc/pad.h>
#include <ogc/gx.h>
#include <ogc/gu.h>
#include <ogc/cache.h>
#include <ogc/color.h>
#include "graphics.h"

#define LCD_W LCD_WIDTH
#define LCD_H LCD_HEIGHT

#define SHIM_FIFO_SIZE (256*1024)

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

static uint8_t  bufs[2][LCD_W * LCD_H];
static uint8_t *display_buf = bufs[0];
static uint8_t *draw_buf    = bufs[1];
uint16_t Palette[256];

static uint8_t  color_idx = 0;
static uint8_t  transparent_idx = 0;
static int      clip_x0 = 0, clip_y0 = 0, clip_x1 = LCD_W, clip_y1 = LCD_H;

static int      text_x = 0, text_y = 0;
static uint8_t  text_fg = 0, text_bg = 255, text_trans = 255;
static uint8_t  text_sx = 1, text_sy = 1;

/* GX / video state */
#ifdef GC_PRESENT_GX
static uint16_t *rgbtex;
static GXTexObj texobj;
static Mtx model;
static Mtx44 proj;
#endif
static void *xfb[2];          /* uncached (K1) pointers, as the video interface wants them */
static uint32_t *xfb_cpu[2];  /* the same memory through the cached (K0) mapping, for CPU writes */
static GXRModeObj *rmode;
static int whichfb;

/* ------------------------------------------------------------------------ */
/* Presentation                                                              */
/* ------------------------------------------------------------------------ */

/*
 * Default presentation: the indexed frame is converted to YCbCr on the CPU and
 * written straight into the external framebuffer that the video interface
 * scans out. There is no GX texture involved, so nothing can show a stale
 * frame: emulators with a fast/partial texture-cache hash (Dolphin's default
 * "Texture Cache Accuracy") can otherwise miss small changes such as a cursor
 * moving, and keep drawing the old texture until something bigger changes.
 *
 * Build with -DGC_PRESENT_GX to use the GX textured-quad path instead.
 */

/* CE palette entries are 1555 where bit 15 is the low bit of green (6-bit green). */
static uint32_t ycbycr_from_1555(uint16_t v)
{
    int r5 = (v >> 10) & 31, b5 = v & 31;
    int g6 = (((v >> 5) & 31) << 1) | (v >> 15);
    int r = (r5 << 3) | (r5 >> 2);
    int g = (g6 << 2) | (g6 >> 4);
    int b = (b5 << 3) | (b5 >> 2);

    /* BT.601, studio range. Integer maths with rounding. */
    int y  = ((  66 * r + 129 * g +  25 * b + 128) >> 8) + 16;
    int cb = (( -38 * r -  74 * g + 112 * b + 128) >> 8) + 128;
    int cr = (( 112 * r -  94 * g -  18 * b + 128) >> 8) + 128;
    if (y  < 16) y  = 16;
    if (y  > 235) y  = 235;
    if (cb < 16) cb = 16;
    if (cb > 240) cb = 240;
    if (cr < 16) cr = 16;
    if (cr > 240) cr = 240;

    /* Two horizontally adjacent pixels of the same colour: Y Cb Y Cr. */
    return ((uint32_t)y << 24) | ((uint32_t)cb << 16) | ((uint32_t)y << 8) | (uint32_t)cr;
}

static void present_cpu(void)
{
    if (!rmode || !xfb_cpu[whichfb]) return;

    uint32_t lut[256];
    for (int i = 0; i < 256; i++) lut[i] = ycbycr_from_1555(Palette[i]);

    const int w = rmode->fbWidth;            /* pixels per XFB row */
    const int h = rmode->xfbHeight;          /* rows */
    const int words = w / 2;                 /* one word = two pixels */
    uint32_t *dst = xfb_cpu[whichfb];
    const uint32_t *prev_row = NULL;
    int prev_sy = -1;

    for (int y = 0; y < h; y++, dst += words) {
        int sy = (y * LCD_H) / h;
        if (sy == prev_sy) {                 /* vertical doubling: repeat the last row */
            memcpy(dst, prev_row, (size_t)words * 4);
        } else {
            const uint8_t *src = display_buf + sy * LCD_W;
            if (w == 2 * LCD_W) {            /* 640 wide: each source pixel is exactly one word */
                for (int x = 0; x < LCD_W; x++) dst[x] = lut[src[x]];
            } else {                         /* other widths: nearest neighbour */
                for (int x = 0; x < words; x++) dst[x] = lut[src[(x * 2 * LCD_W) / w]];
            }
        }
        prev_row = dst;
        prev_sy = sy;
    }

    DCFlushRange(xfb_cpu[whichfb], (u32)(w * h * 2));
    VIDEO_SetNextFramebuffer(xfb[whichfb]);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    whichfb ^= 1;
}

#ifdef GC_PRESENT_GX
/* CE palette entries are 1555 where bit 15 is the low bit of green (6-bit green). */
static uint16_t rgb565_from_1555(uint16_t v)
{
    unsigned r5 = (v >> 10) & 31, b5 = v & 31;
    unsigned g6 = (((v >> 5) & 31) << 1) | (v >> 15);
    return (uint16_t)((r5 << 11) | (g6 << 5) | b5);
}

static void present_gx(void)
{
    if (!rgbtex || !rmode) return;

    uint16_t lut[256];
    for (int i = 0; i < 256; i++) lut[i] = rgb565_from_1555(Palette[i]);

    /*
     * GX_TF_RGB565 is stored as 4x4-pixel tiles (16 texels per tile, row-major
     * inside a tile), not as a linear bitmap. Tiles are laid out row by row,
     * so we can write the texture strictly sequentially.
     */
    uint16_t *out = rgbtex;
    for (int ty = 0; ty < LCD_H / 4; ty++) {
        const uint8_t *row = display_buf + ty * 4 * LCD_W;
        for (int tx = 0; tx < LCD_W / 4; tx++, out += 16) {
            const uint8_t *p = row + tx * 4;
            for (int r = 0; r < 4; r++, p += LCD_W) {
                out[r * 4 + 0] = lut[p[0]];
                out[r * 4 + 1] = lut[p[1]];
                out[r * 4 + 2] = lut[p[2]];
                out[r * 4 + 3] = lut[p[3]];
            }
        }
    }
    DCFlushRange(rgbtex, LCD_W * LCD_H * 2);

    GX_InitTexObj(&texobj, rgbtex, LCD_W, LCD_H, GX_TF_RGB565, GX_CLAMP, GX_CLAMP, GX_FALSE);
    /* Keep pixels crisp when the EFB height is an integer multiple of 240 (NTSC 480). */
    {
        u8 filt = (rmode->efbHeight % LCD_H == 0) ? GX_NEAR : GX_LINEAR;
        GX_InitTexObjFilterMode(&texobj, filt, filt);
    }
    GX_InvalidateTexAll();
    GX_LoadTexObj(&texobj, GX_TEXMAP0);
    GX_SetTevOrder(GX_TEVSTAGE0, GX_TEXCOORD0, GX_TEXMAP0, GX_COLOR0A0);
    GX_SetTevOp(GX_TEVSTAGE0, GX_REPLACE);
    GX_SetVtxDesc(GX_VA_POS, GX_DIRECT);
    GX_SetVtxDesc(GX_VA_TEX0, GX_DIRECT);
    GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_POS, GX_POS_XYZ, GX_F32, 0);
    GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_TEX0, GX_TEX_ST, GX_F32, 0);
    GX_SetNumTexGens(1);
    GX_SetNumTevStages(1);
    GX_SetNumChans(0);
    GX_SetCullMode(GX_CULL_NONE);
    GX_SetZMode(GX_FALSE, GX_LEQUAL, GX_FALSE);
    GX_SetColorUpdate(GX_TRUE);
    GX_SetAlphaUpdate(GX_FALSE);
    GX_SetBlendMode(GX_BM_NONE, GX_BL_ONE, GX_BL_ZERO, GX_LO_CLEAR);

    /* The quad is drawn over the WHOLE efb; the display copy below takes the whole efb too. */
    GX_SetViewport(0, 0, rmode->fbWidth, rmode->efbHeight, 0, 1);
    GX_SetScissor(0, 0, rmode->fbWidth, rmode->efbHeight);
    guOrtho(proj, 0, LCD_H, 0, LCD_W, 0, 1);
    GX_LoadProjectionMtx(proj, GX_ORTHOGRAPHIC);
    guMtxIdentity(model);
    GX_LoadPosMtxImm(model, GX_PNMTX0);

    GX_Begin(GX_QUADS, GX_VTXFMT0, 4);
      GX_Position3f32(0, 0, 0);          GX_TexCoord2f32(0, 0);
      GX_Position3f32(LCD_W, 0, 0);      GX_TexCoord2f32(1, 0);
      GX_Position3f32(LCD_W, LCD_H, 0);  GX_TexCoord2f32(1, 1);
      GX_Position3f32(0, LCD_H, 0);      GX_TexCoord2f32(0, 1);
    GX_End();

    /* Copy first, then wait for the copy to finish before handing the XFB to the VI. */
    GX_CopyDisp(xfb[whichfb], GX_TRUE);
    GX_DrawDone();
    VIDEO_SetNextFramebuffer(xfb[whichfb]);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    whichfb ^= 1;
}

#endif

static void present(void)
{
#ifdef GC_PRESENT_GX
    present_gx();
#else
    present_cpu();
#endif
}

void DrawBegin(void)
{
    VIDEO_Init();
    PAD_Init();
    rmode = VIDEO_GetPreferredMode(NULL);
    xfb_cpu[0] = (uint32_t *)SYS_AllocateFramebuffer(rmode);
    xfb_cpu[1] = (uint32_t *)SYS_AllocateFramebuffer(rmode);
    xfb[0] = MEM_K0_TO_K1(xfb_cpu[0]);
    xfb[1] = MEM_K0_TO_K1(xfb_cpu[1]);
    VIDEO_Configure(rmode);
    /* Fresh XFB memory is zeroed YCbCr, which displays as solid green. Start from black. */
    VIDEO_ClearFrameBuffer(rmode, xfb[0], COLOR_BLACK);
    VIDEO_ClearFrameBuffer(rmode, xfb[1], COLOR_BLACK);
    VIDEO_SetNextFramebuffer(xfb[0]);
    VIDEO_SetBlack(FALSE);
    VIDEO_Flush();
    VIDEO_WaitVSync();
    if (rmode->viTVMode & VI_NON_INTERLACE) VIDEO_WaitVSync();

#ifdef GC_PRESENT_GX
    {
        /* GX needs a 32-byte-aligned command FIFO; passing NULL/0 overflows immediately. */
        static void *gx_fifo = NULL;
        if (!gx_fifo) {
            gx_fifo = memalign(32, SHIM_FIFO_SIZE);
            memset(gx_fifo, 0, SHIM_FIFO_SIZE);
        }
        GX_Init(gx_fifo, SHIM_FIFO_SIZE);
    }
    GX_SetCopyClear((GXColor){0, 0, 0, 255}, GX_MAX_Z24);

    /*
     * Standard libogc display setup. The EFB-to-XFB copy must cover the same
     * area the viewport draws into (the full EFB). Copying only a 320x240
     * corner of a 640x480 EFB shows one zoomed-in quadrant and leaves the rest
     * of the XFB untouched.
     */
    GX_SetViewport(0, 0, rmode->fbWidth, rmode->efbHeight, 0, 1);
    GX_SetDispCopySrc(0, 0, rmode->fbWidth, rmode->efbHeight);
    {
        f32 yscale = GX_GetYScaleFactor(rmode->efbHeight, rmode->xfbHeight);
        u32 xfbHeight = GX_SetDispCopyYScale(yscale);
        GX_SetDispCopyDst(rmode->fbWidth, xfbHeight);
    }
    GX_SetScissor(0, 0, rmode->fbWidth, rmode->efbHeight);
    GX_SetCopyFilter(rmode->aa, rmode->sample_pattern, GX_TRUE, rmode->vfilter);
    GX_SetFieldMode(rmode->field_rendering, ((rmode->viHeight == 2 * rmode->xfbHeight) ? GX_TRUE : GX_FALSE));
    GX_SetPixelFmt(GX_PF_RGB8_Z24, GX_ZC_LINEAR);
    GX_SetCullMode(GX_CULL_NONE);
    GX_SetZMode(GX_FALSE, GX_ALWAYS, GX_FALSE);
    GX_SetColorUpdate(GX_TRUE);
    GX_SetAlphaUpdate(GX_FALSE);
    GX_SetBlendMode(GX_BM_NONE, GX_BL_ONE, GX_BL_ZERO, GX_LO_CLEAR);
    GX_SetNumChans(0); GX_SetNumTexGens(1); GX_SetNumTevStages(1);
    GX_SetTevOp(GX_TEVSTAGE0, GX_REPLACE);
    GX_SetTevOrder(GX_TEVSTAGE0, GX_TEXCOORD0, GX_TEXMAP0, GX_COLOR0A0);
    GX_SetVtxDesc(GX_VA_POS, GX_DIRECT); GX_SetVtxDesc(GX_VA_TEX0, GX_DIRECT);
    GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_POS, GX_POS_XYZ, GX_F32, 0);
    GX_SetVtxAttrFmt(GX_VTXFMT0, GX_VA_TEX0, GX_TEX_ST, GX_F32, 0);

    if (!rgbtex) rgbtex = memalign(32, LCD_W * LCD_H * 2);
#endif

    SetDefaultPalette(MODE_8BPP);
    memset(bufs, 0, sizeof bufs);
    display_buf = bufs[0];
    draw_buf = bufs[1];
    color_idx = 0; transparent_idx = 0;
    clip_x0 = 0; clip_y0 = 0; clip_x1 = LCD_W; clip_y1 = LCD_H;
    text_x = text_y = 0; text_fg = 0; text_bg = 255; text_trans = 255; text_sx = text_sy = 1;
    present();
}

void DrawEnd(void)
{
#ifdef GC_PRESENT_GX
    if (rgbtex) free(rgbtex);
    rgbtex = NULL;
#endif
}

/* ------------------------------------------------------------------------ */
/* Palette                                                                   */
/* ------------------------------------------------------------------------ */

void SetDefaultPalette(GraphicsMode mode)
{
    (void)mode;
    for (int i = 0; i < 256; i++) {
        unsigned r = (i >> 5) & 7, g = (i >> 2) & 7, b = i & 3;
        r = (r << 5) | (r << 2) | (r >> 1);
        g = (g << 5) | (g << 2) | (g >> 1);
        b = (b << 6) | (b << 4) | (b << 2) | b;
        Palette[i] = RGBTo1555(r, g, b);
    }
}

/* `size` is in BYTES (as on the calculator); `palette` is an array of native uint16_t 1555 entries. */
void SetPalette(const void *palette, uint24_t size, uint8_t offset)
{
    const uint16_t *p = (const uint16_t *)palette;
    unsigned count = size / 2;
    if (!p) return;
    for (unsigned i = 0; i < count && (offset + i) < 256; i++)
        Palette[offset + i] = p[i];
}

/* ------------------------------------------------------------------------ */
/* Buffers                                                                   */
/* ------------------------------------------------------------------------ */

static uint8_t *other_buf(void) { return display_buf == bufs[0] ? bufs[1] : bufs[0]; }

void SetDraw(uint8_t location) { draw_buf = (location == LOC_SCREEN) ? display_buf : other_buf(); }
uint8_t GetDraw(void) { return draw_buf == display_buf ? LOC_SCREEN : LOC_BUFFER; }
void SetDrawScreen(void) { SetDraw(LOC_SCREEN); }
void SetDrawBuffer(void) { SetDraw(LOC_BUFFER); }

void SwapDraw(void)
{
    uint8_t *old_display = display_buf;
    display_buf = draw_buf;
    draw_buf = old_display;
    present();
}

void Wait(void) { present(); }

void Blit(DrawLocation src)
{
    if (src == LOC_BUFFER) memcpy(display_buf, other_buf(), LCD_W * LCD_H);
    else                   memcpy(other_buf(), display_buf, LCD_W * LCD_H);
    present();
}
void BlitBuffer(void) { Blit(LOC_BUFFER); }
void BlitScreen(void) { Blit(LOC_SCREEN); }

/* ------------------------------------------------------------------------ */
/* Drawing (mirrors desk_shim)                                               */
/* ------------------------------------------------------------------------ */

uint8_t SetColor(uint8_t i) { uint8_t o = color_idx; color_idx = i; return o; }
uint8_t SetTransparentColor(uint8_t i) { uint8_t o = transparent_idx; transparent_idx = i; return o; }

void SetClipRegion(int xmin, int ymin, int xmax, int ymax)
{
    clip_x0 = xmin < 0 ? 0 : xmin;
    clip_y0 = ymin < 0 ? 0 : ymin;
    clip_x1 = xmax > LCD_W ? LCD_W : xmax;
    clip_y1 = ymax > LCD_H ? LCD_H : ymax;
}

void FillScreen(uint8_t c) { memset(draw_buf, c, LCD_W * LCD_H); }
void ZeroScreen(void) { memset(draw_buf, 0, LCD_W * LCD_H); }

static inline void put(int x, int y, uint8_t c)
{
    if (x >= clip_x0 && x < clip_x1 && y >= clip_y0 && y < clip_y1) draw_buf[y * LCD_W + x] = c;
}

void SetPixel(uint24_t x, uint8_t y) { put((int)x, y, color_idx); }
uint8_t GetPixel(uint24_t x, uint8_t y)
{
    return (x < LCD_W && y < LCD_H) ? draw_buf[y * LCD_W + x] : 0;
}

void HorizLine(int x, int y, int len)
{
    if (len <= 0 || y < clip_y0 || y >= clip_y1) return;
    int x0 = x < clip_x0 ? clip_x0 : x, x1 = (x + len) > clip_x1 ? clip_x1 : (x + len);
    if (x1 > x0) memset(draw_buf + y * LCD_W + x0, color_idx, x1 - x0);
}
void HorizLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { HorizLine((int)x, y, (int)len); }

void VertLine(int x, int y, int len)
{
    if (len <= 0 || x < clip_x0 || x >= clip_x1) return;
    int y0 = y < clip_y0 ? clip_y0 : y, y1 = (y + len) > clip_y1 ? clip_y1 : (y + len);
    for (int j = y0; j < y1; j++) draw_buf[j * LCD_W + x] = color_idx;
}
void VertLine_NoClip(uint24_t x, uint8_t y, uint24_t len) { VertLine((int)x, y, (int)len); }

void Line(int x0, int y0, int x1, int y1)
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
void Line_NoClip(uint24_t x0, uint8_t y0, uint24_t x1, uint8_t y1) { Line((int)x0, y0, (int)x1, y1); }

void FillRectangle(int x, int y, int w, int h)
{
    for (int j = 0; j < h; j++) HorizLine(x, y + j, w);
}
void FillRectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { FillRectangle((int)x, y, (int)w, h); }

void Rectangle(int x, int y, int w, int h)
{
    if (w <= 0 || h <= 0) return;
    HorizLine(x, y, w);
    HorizLine(x, y + h - 1, w);
    VertLine(x, y, h);
    VertLine(x + w - 1, y, h);
}
void Rectangle_NoClip(uint24_t x, uint8_t y, uint24_t w, uint8_t h) { Rectangle((int)x, y, (int)w, h); }

void Circle(int cx, int cy, uint24_t radius)
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
void Circle_NoClip(uint24_t x, uint8_t y, uint8_t r) { Circle((int)x, y, r); }

void FillCircle(int cx, int cy, uint24_t radius)
{
    int r = (int)radius;
    for (int dy = -r; dy <= r; dy++) {
        int dx = (int)floor(sqrt((double)(r * r - dy * dy)) + 0.5);
        HorizLine(cx - dx, cy + dy, 2 * dx + 1);
    }
}
void FillCircle_NoClip(uint24_t x, uint8_t y, uint8_t r) { FillCircle((int)x, y, r); }

Sprite *internal_init_sprite(void *mem, uint8_t w, uint8_t h)
{
    Sprite *s = (Sprite *)mem;
    if (s) { s->width = w; s->height = h; }
    return s;
}

Sprite *MallocSprite(uint8_t w, uint8_t h)
{
    return internal_init_sprite(malloc(2 + (size_t)w * h), w, h);
}

void LCDShiftLeft(uint24_t n)
{
    if (n == 0 || n >= LCD_W) return;
    for (int y = 0; y < LCD_H; y++) memmove(draw_buf + y * LCD_W, draw_buf + y * LCD_W + n, LCD_W - n);
}
void LCDShiftRight(uint24_t n)
{
    if (n == 0 || n >= LCD_W) return;
    for (int y = 0; y < LCD_H; y++) memmove(draw_buf + y * LCD_W + n, draw_buf + y * LCD_W, LCD_W - n);
}
void LCDShiftUp(uint24_t n)
{
    if (n == 0 || n >= LCD_H) return;
    memmove(draw_buf, draw_buf + n * LCD_W, (size_t)(LCD_H - n) * LCD_W);
}
void LCDShiftDown(uint24_t n)
{
    if (n == 0 || n >= LCD_H) return;
    memmove(draw_buf + n * LCD_W, draw_buf, (size_t)(LCD_H - n) * LCD_W);
}

/*
 * Sprite blit. Output is identical to desk_shim's per-pixel version, but the
 * common unscaled case clips once per sprite and copies whole rows. The Gekko
 * is far slower than a desktop CPU, so a per-pixel clip test here is what
 * makes tilemap-heavy frames take longer than a vblank.
 */
static void blit_sprite(const Sprite *s, int x, int y, int sw, int sh, int transparent)
{
    if (!s || sw < 1 || sh < 1) return;
    const int w = s->width, h = s->height;

    if (sw == 1 && sh == 1) {
        int sx0 = clip_x0 - x; if (sx0 < 0) sx0 = 0;
        int sx1 = clip_x1 - x; if (sx1 > w) sx1 = w;
        int sy0 = clip_y0 - y; if (sy0 < 0) sy0 = 0;
        int sy1 = clip_y1 - y; if (sy1 > h) sy1 = h;
        if (sx0 >= sx1 || sy0 >= sy1) return;
        const int n = sx1 - sx0;
        const uint8_t t = transparent_idx;
        for (int j = sy0; j < sy1; j++) {
            uint8_t *dst = draw_buf + (y + j) * LCD_W + x + sx0;
            const uint8_t *src = s->data + j * w + sx0;
            if (!transparent) {
                memcpy(dst, src, (size_t)n);
            } else {
                for (int i = 0; i < n; i++) {
                    uint8_t c = src[i];
                    if (c != t) dst[i] = c;
                }
            }
        }
        return;
    }

    for (int j = 0; j < h; j++) {
        for (int i = 0; i < w; i++) {
            uint8_t c = s->data[j * w + i];
            if (transparent && c == transparent_idx) continue;
            for (int b = 0; b < sh; b++)
                for (int a = 0; a < sw; a++)
                    put(x + i * sw + a, y + j * sh + b, c);
        }
    }
}

void DrawSprite(const Sprite *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 0); }
void DrawSprite_NoClip(const Sprite *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 0); }
void DrawTransparentSprite(const Sprite *s, int x, int y) { blit_sprite(s, x, y, 1, 1, 1); }
void DrawTransparentSprite_NoClip(const Sprite *s, uint24_t x, uint8_t y) { blit_sprite(s, (int)x, y, 1, 1, 1); }
void DrawScaledSprite_NoClip(const Sprite *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 0); }
void DrawScaledTransparentSprite_NoClip(const Sprite *s, uint24_t x, uint8_t y, uint8_t ws, uint8_t hs)
{ blit_sprite(s, (int)x, y, ws, hs, 1); }

Sprite *GetSprite(Sprite *out, int x, int y)
{
    for (int j = 0; j < out->height; j++)
        for (int i = 0; i < out->width; i++) {
            int px = x + i, py = y + j;
            out->data[j * out->width + i] =
                (px >= 0 && px < LCD_W && py >= 0 && py < LCD_H) ? draw_buf[py * LCD_W + px] : 0;
        }
    return out;
}

/* Naming follows graphx: FlipSpriteY mirrors left-right, FlipSpriteX mirrors top-bottom. */
Sprite *FlipSpriteY(const Sprite *in, Sprite *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[j * in->width + (in->width - 1 - i)] = in->data[j * in->width + i];
    return out;
}

Sprite *FlipSpriteX(const Sprite *in, Sprite *out)
{
    out->width = in->width; out->height = in->height;
    for (int j = 0; j < in->height; j++)
        for (int i = 0; i < in->width; i++)
            out->data[(in->height - 1 - j) * in->width + i] = in->data[j * in->width + i];
    return out;
}

static void draw_tilemap(const Tilemap *t, uint24_t xo, uint24_t yo, int transparent)
{
    unsigned tw = t->tile_width ? t->tile_width : 1, th = t->tile_height ? t->tile_height : 1;
    unsigned col0 = xo / tw, row0 = yo / th;
    int px0 = (int)t->x_loc - (int)(xo % tw), py0 = (int)t->y_loc - (int)(yo % th);
    for (unsigned r = 0; r < t->draw_height; r++) {
        for (unsigned c = 0; c < t->draw_width; c++) {
            unsigned mc = col0 + c, mr = row0 + r;
            if (mc >= t->width || mr >= t->height) continue;
            const Sprite *s = t->tiles[t->map[mr * t->width + mc]];
            blit_sprite(s, px0 + (int)(c * tw), py0 + (int)(r * th), 1, 1, transparent);
        }
    }
}
void DrawTilemap(const Tilemap *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void DrawTilemap_NoClip(const Tilemap *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 0); }
void DrawTransparentTilemap(const Tilemap *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }
void DrawTransparentTilemap_NoClip(const Tilemap *t, uint24_t xo, uint24_t yo) { draw_tilemap(t, xo, yo, 1); }

/* ------------------------------------------------------------------------ */
/* Text                                                                      */
/* ------------------------------------------------------------------------ */

uint8_t SetTextFGColor(uint8_t c) { uint8_t o = text_fg; text_fg = c; return o; }
uint8_t SetTextBGColor(uint8_t c) { uint8_t o = text_bg; text_bg = c; return o; }
uint8_t SetTextTransparentColor(uint8_t c) { uint8_t o = text_trans; text_trans = c; return o; }
void SetTextScale(uint8_t ws, uint8_t hs) { text_sx = ws ? ws : 1; text_sy = hs ? hs : 1; }
void SetTextXY(int x, int y) { text_x = x; text_y = y; }
int GetTextX(void) { return text_x; }
int GetTextY(void) { return text_y; }
uint24_t GetCharWidth(const char c) { (void)c; return 8u * text_sx; }
uint24_t GetStringWidth(const char *s) { return (uint24_t)strlen(s) * 8u * text_sx; }

void PrintChar(const char ch)
{
    unsigned idx = (unsigned char)ch;
    if (idx < 32 || idx > 126) idx = '?';
    const uint8_t *g = font8x8[idx - 32];

    uint8_t saved = color_idx;
    if (text_bg != text_trans) {
        color_idx = text_bg;
        FillRectangle(text_x, text_y, 8 * text_sx, 8 * text_sy);
    }
    color_idx = text_fg;
    for (int row = 0; row < 8; row++)
        for (int col = 0; col < 8; col++)
            if ((g[row] >> col) & 1)
                FillRectangle(text_x + col * text_sx, text_y + row * text_sy, text_sx, text_sy);
    color_idx = saved;
    text_x += 8 * text_sx;
}

void PrintString(const char *s) { while (*s) PrintChar(*s++); }

void PrintStringXY(const char *s, int x, int y)
{
    SetTextXY(x, y);
    PrintString(s);
}

void PrintInt(int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*d", (int)length, n);
    PrintString(buf);
}

void PrintUInt(unsigned int n, uint8_t length)
{
    char buf[32];
    snprintf(buf, sizeof buf, "%0*u", (int)length, n);
    PrintString(buf);
}