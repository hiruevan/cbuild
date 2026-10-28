#define SDL_MAIN_HANDLED
#include <SDL.h>
#include <stdlib.h>

#include "keypadc.h"
#include "ce_internal.h"

volatile uint16_t kb_Data[8];

/*
 * Desktop key bindings (calculator key -> keyboard key):
 *   D-pad   = Arrow keys        2nd   = Z        Alpha = X
 *   Clear   = C                 Mode  = Esc      Del   = Backspace
 *   Enter   = Return            Graph/Trace/Zoom/Window/Y= = F5/F4/F3/F2/F1
 *   Stat = S, Prgm = P, Vars = V, Math = M
 *   0-9 = number row, + - * / = keypad
 * Closing the window behaves like the game's Mode+2nd force-exit combo.
 */
typedef struct { SDL_Scancode sc; uint8_t group; uint8_t mask; } KeyMap;

static const KeyMap keymap[] = {
    { SDL_SCANCODE_DOWN, 7, 0x01 }, { SDL_SCANCODE_LEFT, 7, 0x02 },
    { SDL_SCANCODE_RIGHT, 7, 0x04 }, { SDL_SCANCODE_UP, 7, 0x08 },
    { SDL_SCANCODE_Z, 1, 0x20 },          /* 2nd   */
    { SDL_SCANCODE_X, 2, 0x80 },          /* Alpha */
    { SDL_SCANCODE_C, 6, 0x40 },          /* Clear */
    { SDL_SCANCODE_ESCAPE, 1, 0x40 },     /* Mode  */
    { SDL_SCANCODE_BACKSPACE, 1, 0x80 },  /* Del   */
    { SDL_SCANCODE_RETURN, 6, 0x01 },     /* Enter */
    { SDL_SCANCODE_KP_ENTER, 6, 0x01 },
    { SDL_SCANCODE_F1, 1, 0x10 }, { SDL_SCANCODE_F2, 1, 0x08 },
    { SDL_SCANCODE_F3, 1, 0x04 }, { SDL_SCANCODE_F4, 1, 0x02 },
    { SDL_SCANCODE_F5, 1, 0x01 },
    { SDL_SCANCODE_M, 2, 0x40 }, { SDL_SCANCODE_S, 4, 0x80 },
    { SDL_SCANCODE_P, 4, 0x40 }, { SDL_SCANCODE_V, 5, 0x40 },
    { SDL_SCANCODE_0, 3, 0x01 }, { SDL_SCANCODE_1, 3, 0x02 }, { SDL_SCANCODE_4, 3, 0x04 },
    { SDL_SCANCODE_7, 3, 0x08 }, { SDL_SCANCODE_2, 4, 0x02 }, { SDL_SCANCODE_5, 4, 0x04 },
    { SDL_SCANCODE_8, 4, 0x08 }, { SDL_SCANCODE_3, 5, 0x02 }, { SDL_SCANCODE_6, 5, 0x04 },
    { SDL_SCANCODE_9, 5, 0x08 },
    { SDL_SCANCODE_KP_PLUS, 6, 0x02 }, { SDL_SCANCODE_KP_MINUS, 6, 0x04 },
    { SDL_SCANCODE_KP_MULTIPLY, 6, 0x08 }, { SDL_SCANCODE_KP_DIVIDE, 6, 0x10 },
    { SDL_SCANCODE_PERIOD, 4, 0x01 }, { SDL_SCANCODE_COMMA, 3, 0x10 },
};

static int quit_requested = 0;
static int quit_scans = 0;

void kb_Scan(void)
{
    if (ce_video_ready()) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) quit_requested = 1;
        }

        const Uint8 *ks = SDL_GetKeyboardState(NULL);
        for (int g = 0; g < 8; g++) kb_Data[g] = 0;
        for (size_t i = 0; i < sizeof keymap / sizeof keymap[0]; i++)
            if (ks[keymap[i].sc]) kb_Data[keymap[i].group] |= keymap[i].mask;

        ce_present_if_due();
    }

    if (quit_requested) {
        kb_Data[1] |= 0x40 | 0x20;
        if (++quit_scans > 180) { SDL_Quit(); exit(0); }
    }
}

uint8_t kb_ScanGroup(uint8_t row)
{
    kb_Scan();
    return (row >= 1 && row <= 7) ? (uint8_t)kb_Data[row] : 0;
}

uint8_t kb_AnyKey(void)
{
    kb_Scan();
    for (int g = 1; g < 8; g++) if (kb_Data[g]) return 1;
    return 0;
}

void kb_Reset(void) {}
void kb_SetMode(uint8_t mode) { (void)mode; }
void kb_DisableOnLatch(void) {}
void kb_ClearOnLatch(void) {}
bool kb_On(void) { return false; }
