#ifndef CE_SHIM_TICE_H
#define CE_SHIM_TICE_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

#ifdef _WIN32
static inline int random(void) { return rand(); }
static inline void srandom(unsigned int seed) { srand(seed); }
#endif

typedef uint32_t uint24_t;
typedef int32_t  int24_t;

#endif
