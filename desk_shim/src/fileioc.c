#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include "fileioc.h"

#define MAX_SLOTS 6

typedef struct {
    FILE *fp;
    void *snapshot;
} Slot;

static Slot slots[MAX_SLOTS];
static char *base_dir = NULL;

static const char *get_base(void)
{
    if (!base_dir) {
        char *p = SDL_GetPrefPath("cbuild-apps", CBUILD_APP_NAME);
        base_dir = p ? p : SDL_strdup("./");
    }
    return base_dir;
}

static void make_path(const char *name, char *out, size_t n)
{
    snprintf(out, n, "%s%s.sav", get_base(), name);
}

uint8_t ti_Open(const char *name, const char *mode)
{
    char path[1024];
    make_path(name, path, sizeof path);

    char m[8];
    size_t len = strlen(mode);
    if (len + 2 > sizeof m) return 0;
    memcpy(m, mode, len);
    if (strchr(mode, 'b') == NULL) { m[len] = 'b'; m[len + 1] = '\0'; }
    else m[len] = '\0';

    for (int i = 1; i < MAX_SLOTS; i++) {
        if (!slots[i].fp) {
            FILE *fp = fopen(path, m);
            if (!fp) return 0;
            slots[i].fp = fp;
            slots[i].snapshot = NULL;
            return (uint8_t)i;
        }
    }
    return 0;
}

static FILE *get(uint8_t slot)
{
    return (slot > 0 && slot < MAX_SLOTS) ? slots[slot].fp : NULL;
}

int ti_Close(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return 0;
    fclose(fp);
    free(slots[slot].snapshot);
    slots[slot].fp = NULL;
    slots[slot].snapshot = NULL;
    return 1;
}

size_t ti_Read(void *data, size_t size, size_t count, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fread(data, size, count, fp) : 0;
}

size_t ti_Write(const void *data, size_t size, size_t count, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fwrite(data, size, count, fp) : 0;
}

int ti_PutC(char ch, uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fputc((unsigned char)ch, fp) : -1;
}

int ti_GetC(uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? fgetc(fp) : -1;
}

int ti_Seek(int offset, unsigned origin, uint8_t slot)
{
    FILE *fp = get(slot);
    return (fp && fseek(fp, offset, (int)origin) == 0) ? offset : -1;
}

int ti_Tell(uint8_t slot)
{
    FILE *fp = get(slot);
    return fp ? (int)ftell(fp) : -1;
}

int ti_Rewind(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return -1;
    rewind(fp);
    return 0;
}

uint16_t ti_GetSize(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return 0;
    long cur = ftell(fp);
    fseek(fp, 0, SEEK_END);
    long end = ftell(fp);
    fseek(fp, cur, SEEK_SET);
    return (uint16_t)end;
}

void *ti_GetDataPtr(uint8_t slot)
{
    FILE *fp = get(slot);
    if (!fp) return NULL;
    long cur = ftell(fp);
    fflush(fp);
    fseek(fp, 0, SEEK_END);
    long end = ftell(fp);
    fseek(fp, 0, SEEK_SET);
    free(slots[slot].snapshot);
    slots[slot].snapshot = malloc((size_t)end + 1);
    if (slots[slot].snapshot) {
        size_t got = fread(slots[slot].snapshot, 1, (size_t)end, fp);
        (void)got;
    }
    fseek(fp, cur, SEEK_SET);
    return slots[slot].snapshot;
}

int ti_Delete(const char *name)
{
    char path[1024];
    make_path(name, path, sizeof path);
    return remove(path) == 0;
}
