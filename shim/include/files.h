#ifndef CE_SHIM_FILES_H
#define CE_SHIM_FILES_H

#ifndef CBUILD_APP_NAME
#define CBUILD_APP_NAME "data"
#endif

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <random.h>

#if defined(_WIN32) && defined(_WINDOWS_)
#error "files.h defines OpenFile(), ReadFile(), WriteFile() and DeleteFile(), which clash with <windows.h>. Do not include <windows.h> in code that uses files.h."
#endif

#ifdef __cplusplus
extern "C" {
#endif

uint8_t OpenFile(const char *name, const char *mode);
int     CloseFile(uint8_t slot);
size_t  ReadFile(void *data, size_t size, size_t count, uint8_t slot);
size_t  WriteFile(const void *data, size_t size, size_t count, uint8_t slot);
int     PutFileChar(char ch, uint8_t slot);
int     GetFileChar(uint8_t slot);
int     SeekFile(int offset, unsigned origin, uint8_t slot);
int     TellFile(uint8_t slot);
int     RewindFile(uint8_t slot);
uint16_t FileSize(uint8_t slot);
void   *GetFileDataPtr(uint8_t slot);
int     DeleteFile(const char *name);
bool    FileExists(const char *name);

#ifdef __cplusplus
}
#endif

#endif
