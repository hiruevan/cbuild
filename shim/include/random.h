#ifndef CE_SHIM_RANDOM_H
#define CE_SHIM_RANDOM_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdlib.h>

/* The calculator's 24-bit integer types */
typedef uint32_t uint24_t;
typedef int32_t  int24_t;

/* POSIX libc already provides random()/srandom(); Windows does not. */
#ifdef _WIN32
static inline int random(void) { return rand(); }
static inline void srandom(unsigned int seed) { srand(seed); }
#endif

#include "../common/random_common.h"

#endif
