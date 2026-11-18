#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <malloc.h>
#include <unistd.h>
#include <fat.h>
#include <ogc/card.h>
#include <sys/stat.h>
#include "files.h"

/*
 * Storage backends, tried in this order the first time a file is touched:
 *
 *   1. SD card (libfat, sd:/Elyndra/<name>)   - SD Gecko / SD2SP2 on hardware
 *   2. GameCube memory card (slot A, then B)   - one card file per save file
 *   3. RAM                                      - lost on reset
 *
 * Memory card files are loaded fully into RAM when opened and written back
 * when closed (if they were opened for writing), which is how the game uses
 * them (open, read/write a struct, close).
 */

#define SLOT_COUNT 8
#define SAVE_DIR   "sd:/Elyndra"
#define MEM_FILES  16
#define MEM_NAME   32                 /* also the memory card name limit */
#define CARD_MAGIC 0x43424631u        /* 'CBF1' */
#define CARD_HDR   8                  /* magic + length */
#define MAX_FILE   65535

typedef struct {
    char name[MEM_NAME];
    uint8_t *data;
    size_t size, cap;
    int used;
    int ram_only;                     /* card write failed: keep the data in RAM */
} MemFile;

typedef struct {
    FILE *f;                          /* SD backed, or NULL */
    MemFile *m;                       /* RAM / memory-card cache, or NULL */
    size_t pos;
    int write, append;
    int dirty;                        /* memory card file needs writing back */
    int on_card;                      /* m mirrors a memory card file */
    void *snapshot;                   /* ti_GetDataPtr copy of an SD file */
} Slot;

enum { BK_NONE, BK_SD, BK_CARD, BK_RAM };

static Slot slots[SLOT_COUNT];
static MemFile mem[MEM_FILES];
static int backend = BK_NONE;
static int card_chn = -1;
static u32 card_sector;
static void *card_work;

/* ---- backend selection ------------------------------------------------- */

static int card_try(int chn)
{
    s32 sect = 0;
    int tries;
    s32 r = CARD_ERROR_BUSY;

    for (tries = 0; tries < 200; tries++) {            /* up to ~2 s for the card to settle */
        r = CARD_ProbeEx(chn, NULL, &sect);
        if (r != CARD_ERROR_BUSY) break;
        usleep(10000);
    }
    if (r < 0 || sect <= 0) return 0;

    if (!card_work) card_work = memalign(32, CARD_WORKAREA_SIZE);
    if (!card_work) return 0;

    if (CARD_Mount(chn, card_work, NULL) < 0) return 0;
    if (CARD_GetSectorSize(chn, &card_sector) < 0 || card_sector == 0) {
        CARD_Unmount(chn);
        return 0;
    }
    card_chn = chn;
    return 1;
}

static int ensure_backend(void)
{
    if (backend != BK_NONE) return backend;

    if (fatInitDefault()) {
        mkdir(SAVE_DIR, 0777);
        backend = BK_SD;
        return backend;
    }

    CARD_Init("ELYN", "CB");
    if (card_try(CARD_SLOTA) || card_try(CARD_SLOTB)) {
        backend = BK_CARD;
        return backend;
    }

    backend = BK_RAM;
    return backend;
}

/* ---- helpers ----------------------------------------------------------- */

static int valid_name(const char *name) {
    return name && *name && !strchr(name,'/') && !strchr(name,'\\') && !strstr(name,"..")
        && strlen(name) < MEM_NAME;
}
static int make_path(char *out,size_t cap,const char *name) {
    int n = snprintf(out,cap,SAVE_DIR "/%s",name);
    return n>0 && (size_t)n<cap;
}
static MemFile *mem_find(const char *name) {
    for (int i=0;i<MEM_FILES;i++) if (mem[i].used && !strcmp(mem[i].name,name)) return &mem[i];
    return NULL;
}
static MemFile *mem_create(const char *name) {
    for (int i=0;i<MEM_FILES;i++) if (!mem[i].used) {
        memset(&mem[i],0,sizeof mem[i]);
        strcpy(mem[i].name,name); mem[i].used=1; return &mem[i];
    }
    return NULL;
}
static void mem_free(MemFile *m) { free(m->data); memset(m,0,sizeof *m); }
static int mem_reserve(MemFile *m,size_t need) {
    if (need <= m->cap) return 1;
    size_t cap = m->cap ? m->cap : 256;
    while (cap < need) cap *= 2;
    uint8_t *p = realloc(m->data, cap);
    if (!p) return 0;
    m->data = p; m->cap = cap; return 1;
}

/* ---- memory card file <-> MemFile ------------------------------------- */

static u32 rd32(const uint8_t *p) { return ((u32)p[0]<<24)|((u32)p[1]<<16)|((u32)p[2]<<8)|p[3]; }
static void wr32(uint8_t *p, u32 v) { p[0]=v>>24; p[1]=v>>16; p[2]=v>>8; p[3]=v; }

/* Returns 1 and fills m if the card has the file. */
static int card_load(const char *name, MemFile *m)
{
    card_file cf;
    if (CARD_Open(card_chn, name, &cf) < 0) return 0;

    int ok = 0;
    u32 len = (u32)cf.len;
    uint8_t *buf = len ? memalign(32, len) : NULL;

    if (buf && CARD_Read(&cf, buf, len, 0) >= 0 && len >= CARD_HDR && rd32(buf) == CARD_MAGIC) {
        u32 n = rd32(buf + 4);
        if (n <= len - CARD_HDR && n <= MAX_FILE && mem_reserve(m, n + 1)) {
            memcpy(m->data, buf + CARD_HDR, n);
            m->size = n;
            ok = 1;
        }
    }
    free(buf);
    CARD_Close(&cf);
    return ok;
}

/* Returns 1 on success. */
static int card_store(const char *name, const MemFile *m)
{
    u32 total = (u32)m->size + CARD_HDR;
    u32 need = ((total + card_sector - 1) / card_sector) * card_sector;
    uint8_t *buf = memalign(32, need);
    card_file cf;
    int ok = 0;

    if (!buf) return 0;
    memset(buf, 0, need);
    wr32(buf, CARD_MAGIC);
    wr32(buf + 4, (u32)m->size);
    if (m->size) memcpy(buf + CARD_HDR, m->data, m->size);

    int exists = CARD_Open(card_chn, name, &cf) >= 0;
    if (exists && (u32)cf.len != need) {          /* size changed: recreate */
        CARD_Close(&cf);
        CARD_Delete(card_chn, name);
        exists = 0;
    }
    if (!exists && CARD_Create(card_chn, name, need, &cf) < 0) goto done;

    ok = CARD_Write(&cf, buf, need, 0) >= 0;
    CARD_Close(&cf);
done:
    free(buf);
    return ok;
}

/* ---- ti_* API ---------------------------------------------------------- */

uint8_t ti_Open(const char *name,const char *mode) {
    if (!valid_name(name)) return 0;
    int i; for(i=0;i<SLOT_COUNT;i++) if(!slots[i].f && !slots[i].m) break;
    if(i==SLOT_COUNT) return 0;

    int plus = mode && strchr(mode,'+');
    int w = mode && strchr(mode,'w');
    int a = mode && strchr(mode,'a');
    Slot *s = &slots[i];
    memset(s,0,sizeof *s);
    s->write = w || a || plus;
    s->append = a;

    int bk = ensure_backend();

    if (bk == BK_SD) {
        char path[256];
        if (!make_path(path,sizeof path,name)) return 0;
        const char *m = w ? "wb+" : a ? "ab+" : plus ? "rb+" : "rb";
        s->f = fopen(path,m);
        return s->f ? (uint8_t)(i+1) : 0;
    }

    MemFile *mf = mem_find(name);                   /* RAM file (or unsaved card file) */

    if (bk == BK_CARD && !(mf && mf->ram_only)) {
        if (w) {
            if (!mf) mf = mem_create(name);
            if (!mf) return 0;
            mf->size = 0;
            s->dirty = 1;
        } else {
            if (!mf) mf = mem_create(name);
            if (!mf) return 0;
            if (!card_load(name, mf)) {
                if (a) { mf->size = 0; s->dirty = 1; }
                else { mem_free(mf); return 0; }
            }
        }
        s->on_card = 1;
    } else {
        if (w) {
            if (!mf) mf = mem_create(name);
            if (mf) mf->size = 0;
        } else if (!mf && a) {
            mf = mem_create(name);
        }
        if (!mf) return 0;
    }

    s->m = mf;
    s->pos = a ? mf->size : 0;
    return (uint8_t)(i+1);
}
static Slot *get_slot(uint8_t s) {
    if (s<1 || s>SLOT_COUNT) return NULL;
    Slot *p = &slots[s-1];
    return (p->f || p->m) ? p : NULL;
}
int ti_Close(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return 0;
    if (s->f) fclose(s->f);
    if (s->m && s->on_card) {
        if (s->dirty && !card_store(s->m->name, s->m))
            s->m->ram_only = 1;                    /* keep it in RAM so the session still works */
        if (!s->m->ram_only) mem_free(s->m);       /* card is the source of truth */
    }
    free(s->snapshot);
    memset(s,0,sizeof *s);
    return 1;
}
size_t ti_Read(void *d,size_t z,size_t n,uint8_t h) {
    Slot *s=get_slot(h); if(!s||!z) return 0;
    if (s->f) return fread(d,z,n,s->f);
    size_t avail = s->pos < s->m->size ? (s->m->size - s->pos)/z : 0;
    if (n > avail) n = avail;
    memcpy(d, s->m->data + s->pos, n*z);
    s->pos += n*z;
    return n;
}
size_t ti_Write(const void *d,size_t z,size_t n,uint8_t h) {
    Slot *s=get_slot(h); if(!s||!z) return 0;
    if (s->f) return fwrite(d,z,n,s->f);
    if (!s->write) return 0;
    if (s->append) s->pos = s->m->size;
    size_t bytes = z*n;
    if (s->pos + bytes > MAX_FILE) return 0;
    if (!mem_reserve(s->m, s->pos + bytes + 1)) return 0;
    if (s->pos > s->m->size) memset(s->m->data + s->m->size, 0, s->pos - s->m->size);
    memcpy(s->m->data + s->pos, d, bytes);
    s->pos += bytes;
    if (s->pos > s->m->size) s->m->size = s->pos;
    s->dirty = 1;
    return n;
}
int ti_PutC(char c,uint8_t h) {
    Slot *s=get_slot(h); if(!s) return EOF;
    if (s->f) return fputc((unsigned char)c,s->f);
    return ti_Write(&c,1,1,h) == 1 ? (unsigned char)c : EOF;
}
int ti_GetC(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return EOF;
    if (s->f) return fgetc(s->f);
    unsigned char c;
    return ti_Read(&c,1,1,h) == 1 ? c : EOF;
}
int ti_Seek(int o,unsigned origin,uint8_t h) {
    Slot *s=get_slot(h); if(!s) return -1;
    if (s->f) return fseek(s->f,o,origin==0?SEEK_SET:(origin==1?SEEK_CUR:SEEK_END)) == 0 ? o : -1;
    long base = origin==0 ? 0 : origin==1 ? (long)s->pos : (long)s->m->size;
    long np = base + o;
    if (np < 0 || (size_t)np > s->m->size) return -1;
    s->pos = (size_t)np;
    return o;
}
int ti_Tell(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return -1;
    return s->f ? (int)ftell(s->f) : (int)s->pos;
}
int ti_Rewind(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return -1;
    if (s->f) rewind(s->f); else s->pos = 0;
    return 0;
}
uint16_t ti_GetSize(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return 0;
    long n;
    if (s->f) {
        long p=ftell(s->f); fseek(s->f,0,SEEK_END); n=ftell(s->f); fseek(s->f,p,SEEK_SET);
    } else n = (long)s->m->size;
    return (uint16_t)(n<0?0:n>65535?65535:n);
}
void *ti_GetDataPtr(uint8_t h) {
    Slot *s=get_slot(h); if(!s) return NULL;
    if (s->m) {                              /* RAM / card file: pointer to its start */
        if (!mem_reserve(s->m, s->m->size + 1)) return NULL;
        return s->m->data;
    }
    long cur = ftell(s->f);                  /* SD file: snapshot of the whole file */
    fflush(s->f);
    fseek(s->f,0,SEEK_END);
    long end = ftell(s->f);
    fseek(s->f,0,SEEK_SET);
    free(s->snapshot);
    s->snapshot = malloc((size_t)end + 1);
    if (s->snapshot) { size_t got = fread(s->snapshot,1,(size_t)end,s->f); (void)got; }
    fseek(s->f,cur,SEEK_SET);
    return s->snapshot;
}
int ti_Delete(const char *name) {
    if (!valid_name(name)) return 0;
    int bk = ensure_backend();
    if (bk == BK_SD) {
        char path[256];
        if (!make_path(path,sizeof path,name)) return 0;
        return remove(path) == 0;
    }
    int ok = 0;
    MemFile *m = mem_find(name);
    if (m) { mem_free(m); ok = 1; }
    if (bk == BK_CARD && CARD_Delete(card_chn, name) >= 0) ok = 1;
    return ok;
}