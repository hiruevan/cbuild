/*
 * random_common.h - random helpers shared by every platform's random.h.
 * Header-only (static inline) so the calculator build needs no extra .c file.
 * Everything here is built on rand(); seed it with srandom()/srand().
 */
#ifndef CE_SHIM_RANDOM_COMMON_H
#define CE_SHIM_RANDOM_COMMON_H

#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>

/* Inclusive range. lo <= hi. */
static inline int RandomRange(int lo, int hi)
{
    unsigned span = (unsigned)(hi - lo) + 1u;
    return lo + (int)((unsigned)rand() % span);
}

static inline bool RandomChance(int percent)
{
    return RandomRange(0, 99) < percent;
}

/* [0, 1) */
static inline float RandomFloat(void)
{
    return (float)rand() / ((float)RAND_MAX + 1.0f);
}

/* ---------- deterministic hashing / noise (same result on every platform) ---------- */

static inline uint32_t HashU32(uint32_t x)
{
    x ^= x >> 16; x *= 0x7feb352dU;
    x ^= x >> 15; x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
}

static inline uint32_t Hash2D(int x, int y, uint32_t seed)
{
    return HashU32((uint32_t)x * 0x9E3779B1U ^ HashU32((uint32_t)y + seed * 0x85EBCA6BU));
}

static inline int _noise_floor(float v)
{
    int i = (int)v;
    return (v < (float)i) ? i - 1 : i;
}

static inline float _noise_fade(float t)           /* 6t^5 - 15t^4 + 10t^3 */
{
    return t * t * t * (t * (t * 6.0f - 15.0f) + 10.0f);
}

static inline float _noise_lerp(float a, float b, float t)
{
    return a + (b - a) * t;
}

/* Smooth value noise, 0..1 */
static inline float ValueNoise2D(float x, float y, uint32_t seed)
{
    int x0 = _noise_floor(x), y0 = _noise_floor(y);
    float fx = x - (float)x0, fy = y - (float)y0;
    float u = _noise_fade(fx), v = _noise_fade(fy);

    float c00 = (float)(Hash2D(x0,     y0,     seed) & 0xFFFF) / 65535.0f;
    float c10 = (float)(Hash2D(x0 + 1, y0,     seed) & 0xFFFF) / 65535.0f;
    float c01 = (float)(Hash2D(x0,     y0 + 1, seed) & 0xFFFF) / 65535.0f;
    float c11 = (float)(Hash2D(x0 + 1, y0 + 1, seed) & 0xFFFF) / 65535.0f;

    return _noise_lerp(_noise_lerp(c00, c10, u), _noise_lerp(c01, c11, u), v);
}

static inline float _perlin_grad(int ix, int iy, float dx, float dy, uint32_t seed)
{
    switch (Hash2D(ix, iy, seed) & 7u) {
        case 0:  return  dx + dy;
        case 1:  return -dx + dy;
        case 2:  return  dx - dy;
        case 3:  return -dx - dy;
        case 4:  return  dx;
        case 5:  return -dx;
        case 6:  return  dy;
        default: return -dy;
    }
}

/* Classic gradient (Perlin) noise, roughly -1..1 */
static inline float PerlinNoise2D(float x, float y, uint32_t seed)
{
    int x0 = _noise_floor(x), y0 = _noise_floor(y);
    float fx = x - (float)x0, fy = y - (float)y0;
    float u = _noise_fade(fx), v = _noise_fade(fy);

    float n00 = _perlin_grad(x0,     y0,     fx,        fy,        seed);
    float n10 = _perlin_grad(x0 + 1, y0,     fx - 1.0f, fy,        seed);
    float n01 = _perlin_grad(x0,     y0 + 1, fx,        fy - 1.0f, seed);
    float n11 = _perlin_grad(x0 + 1, y0 + 1, fx - 1.0f, fy - 1.0f, seed);

    return _noise_lerp(_noise_lerp(n00, n10, u), _noise_lerp(n01, n11, u), v);
}

/* Several octaves of Perlin noise, normalized to roughly -1..1 */
static inline float FractalNoise2D(float x, float y, uint32_t seed, int octaves)
{
    float sum = 0.0f, amp = 1.0f, norm = 0.0f;
    for (int i = 0; i < octaves; i++) {
        sum  += amp * PerlinNoise2D(x, y, seed + (uint32_t)i);
        norm += amp;
        amp  *= 0.5f;
        x    *= 2.0f;
        y    *= 2.0f;
    }
    return norm > 0.0f ? sum / norm : 0.0f;
}

#endif
