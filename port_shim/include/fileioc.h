#ifndef CE_SHIM_FILEIOC_H
#define CE_SHIM_FILEIOC_H

#ifndef CBUILD_APP_NAME
#define CBUILD_APP_NAME "data"
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

uint8_t ti_Open(const char *name, const char *mode);
int     ti_Close(uint8_t slot);
size_t  ti_Read(void *data, size_t size, size_t count, uint8_t slot);
size_t  ti_Write(const void *data, size_t size, size_t count, uint8_t slot);
int     ti_PutC(char ch, uint8_t slot);
int     ti_GetC(uint8_t slot);
int     ti_Seek(int offset, unsigned origin, uint8_t slot);
int     ti_Tell(uint8_t slot);
int     ti_Rewind(uint8_t slot);
uint16_t ti_GetSize(uint8_t slot);
void   *ti_GetDataPtr(uint8_t slot);
int     ti_Delete(const char *name);

#ifdef __cplusplus
}
#endif

#endif
