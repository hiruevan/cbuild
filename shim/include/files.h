#ifndef CE_SHIM_FILEIOC_H
#define CE_SHIM_FILEIOC_H

#ifndef CBUILD_APP_NAME
#define CBUILD_APP_NAME "data"
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <random.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t OpenFile(const char *name, const char *mode);
int     CloseFile(uint8_t slot);
size_t  ReadFile(void *data, size_t size, size_t count, uint8_t slot);
size_t  WriteFile(const void *data, size_t size, size_t count, uint8_t slot);
int     DeleteFile(const char *name);

#ifdef __cplusplus
}
#endif

#endif
