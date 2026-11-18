/*
 * graphics_common.h - helpers shared by every platform's graphics.h.
 *
 * Header-only on purpose: the calculator build cannot compile extra shim .c
 * files, so everything here is static inline and is written purely in terms of
 * the public graphics API (Line, HorizLine, Palette, ...).
 *
 * Include order: the platform graphics.h declares the API first, then includes
 * this file.
 */
#ifndef CE_SHIM_GRAPHICS_COMMON_H
#define CE_SHIM_GRAPHICS_COMMON_H

#include <stdint.h>

/* ------------------------------------------------------------------ */
/* Points and triangles                                                */
/* ------------------------------------------------------------------ */

typedef struct {
    int x;
    int y;
} Point;

static inline void SwapPoint(Point *a, Point *b)
{
    Point t = *a;
    *a = *b;
    *b = t;
}

static inline void Triangle(Point a, Point b, Point c)
{
    Line(a.x, a.y, b.x, b.y);
    Line(b.x, b.y, c.x, c.y);
    Line(c.x, c.y, a.x, a.y);
}

/* Scanline fill. Uses the current color and respects the clip region. */
static inline void FillTriangle(Point a, Point b, Point c)
{
    /* sort by y: a.y <= b.y <= c.y */
    if (a.y > b.y) SwapPoint(&a, &b);
    if (a.y > c.y) SwapPoint(&a, &c);
    if (b.y > c.y) SwapPoint(&b, &c);

    int total = c.y - a.y;
    if (total == 0) {                       /* all on one row */
        int lo = a.x, hi = a.x;
        if (b.x < lo) lo = b.x;
        if (c.x < lo) lo = c.x;
        if (b.x > hi) hi = b.x;
        if (c.x > hi) hi = c.x;
        HorizLine(lo, a.y, hi - lo + 1);
        return;
    }

    for (int y = a.y; y <= c.y; y++) {
        /* long edge a -> c */
        int x1 = a.x + (int)(((long)(c.x - a.x) * (y - a.y)) / total);
        int x2;
        if (y < b.y || b.y == c.y)          /* upper part: edge a -> b */
            x2 = a.x + (int)(((long)(b.x - a.x) * (y - a.y)) / (b.y - a.y));
        else                                /* lower part: edge b -> c */
            x2 = b.x + (int)(((long)(c.x - b.x) * (y - b.y)) / (c.y - b.y));

        if (x1 > x2) { int t = x1; x1 = x2; x2 = t; }
        HorizLine(x1, y, x2 - x1 + 1);
    }
}

/* ------------------------------------------------------------------ */
/* Palettes (each entry is 1555: bit15 unused, 5 bits per channel)    */
/* ------------------------------------------------------------------ */

/* xLibC / CE default layout: index = RRRGGGBB */
static inline void setup_xlibc_palette(void)
{
    for (int i = 0; i < 256; i++)
    {
        uint8_t r = (i >> 5) & 7;
        uint8_t g = (i >> 2) & 7;
        uint8_t b = i & 3;

        /* Expand 3-bit channels to 5-bit */
        r = (r << 2) | (r >> 1);
        g = (g << 2) | (g >> 1);

        /* Expand 2-bit channel to 5-bit */
        b = (b << 3) | (b << 1) | (b >> 1);

        Palette[i] = (uint16_t)((r << 10) | (g << 5) | b);
    }
}

/* The palette a fresh program starts with. */
static inline void setup_default_palette(void)
{
    setup_xlibc_palette();
}

/* 256 evenly spaced grays. */
static inline void setup_grayscale_palette(void)
{
    for (int i = 0; i < 256; i++) {
        uint16_t v = (uint16_t)(i >> 3);            /* 0..31 */
        Palette[i] = (uint16_t)((v << 10) | (v << 5) | v);
    }
}

/* 6x6x6 "web safe" color cube (0..215), then 40 grays (216..255). */
static inline void setup_web_palette(void)
{
    for (int i = 0; i < 216; i++) {
        uint16_t r = (uint16_t)(((i / 36) % 6) * 31 / 5);
        uint16_t g = (uint16_t)(((i / 6)  % 6) * 31 / 5);
        uint16_t b = (uint16_t)((i % 6)        * 31 / 5);
        Palette[i] = (uint16_t)((r << 10) | (g << 5) | b);
    }
    for (int i = 216; i < 256; i++) {
        uint16_t v = (uint16_t)((i - 216) * 31 / 39);
        Palette[i] = (uint16_t)((v << 10) | (v << 5) | v);
    }
}

/* Nearest index in the xLibC palette for an 8-bit-per-channel color. */
static inline uint8_t RGBTo255(uint8_t r, uint8_t g, uint8_t b)
{
    return (uint8_t)(((r >> 5) << 5) | ((g >> 5) << 2) | (b >> 6));
}

#endif
