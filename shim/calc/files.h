/*
 * Calculator files.h: the shared file API on top of CEdev's fileioc.
 * Files live in the calculator's variable storage.
 */
#ifndef CE_SHIM_CALC_FILES_H
#define CE_SHIM_CALC_FILES_H

#include <fileioc.h>
#include <stdbool.h>

#define OpenFile(...) ti_Open(__VA_ARGS__)
#define CloseFile(...) ti_Close(__VA_ARGS__)
#define ReadFile(...) ti_Read(__VA_ARGS__)
#define WriteFile(...) ti_Write(__VA_ARGS__)
#define PutFileChar(...) ti_PutC(__VA_ARGS__)
#define GetFileChar(...) ti_GetC(__VA_ARGS__)
#define SeekFile(...) ti_Seek(__VA_ARGS__)
#define TellFile(...) ti_Tell(__VA_ARGS__)
#define RewindFile(...) ti_Rewind(__VA_ARGS__)
#define FileSize(...) ti_GetSize(__VA_ARGS__)
#define GetFileDataPtr(...) ti_GetDataPtr(__VA_ARGS__)
#define DeleteFile(...) ti_Delete(__VA_ARGS__)

static inline bool FileExists(const char *name)
{
    uint8_t slot = ti_Open(name, "r");
    if (!slot) return false;
    ti_Close(slot);
    return true;
}

#endif
