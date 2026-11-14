#include <string.h>
#include <ogc/pad.h>
#include <ogc/system.h>
#include "keypadc.h"

volatile uint16_t kb_Data[8];
static uint16_t previous_buttons[4];
static int on_latch = 0;
static int kb_mode = MODE_0_IDLE;

static void set_key(uint16_t code, int down) {
    unsigned row = (code >> 8) & 7;
    if (down) kb_Data[row] |= (uint16_t)(code & 0xff);
}
void kb_Scan(void) {
    PAD_ScanPads();
    memset((void *)kb_Data, 0, sizeof(kb_Data));
    uint16_t b = PAD_ButtonsHeld(0);
    if (b & PAD_BUTTON_A) set_key(kb_KeyEnter,1);
    if (b & PAD_BUTTON_B) set_key(kb_Key2nd,1);
    if (b & PAD_BUTTON_X) set_key(kb_KeyAlpha,1);
    if (b & PAD_BUTTON_Y) set_key(kb_KeyMode,1);
    if (b & PAD_BUTTON_START) set_key(kb_KeyClear,1);
    if (b & PAD_TRIGGER_Z) set_key(kb_KeyDel,1);
    if (b & PAD_TRIGGER_L) set_key(kb_KeyZoom,1);
    if (b & PAD_TRIGGER_R) set_key(kb_KeyWindow,1);
    if (b & PAD_BUTTON_UP) set_key(kb_KeyUp,1);
    if (b & PAD_BUTTON_DOWN) set_key(kb_KeyDown,1);
    if (b & PAD_BUTTON_LEFT) set_key(kb_KeyLeft,1);
    if (b & PAD_BUTTON_RIGHT) set_key(kb_KeyRight,1);
    s8 x=PAD_StickX(0), y=PAD_StickY(0);
    if (x < -48) set_key(kb_KeyLeft,1);
    if (x > 48) set_key(kb_KeyRight,1);
    if (y < -48) set_key(kb_KeyDown,1);
    if (y > 48) set_key(kb_KeyUp,1);
    if (b & PAD_BUTTON_A) on_latch=1;
}
uint8_t kb_ScanGroup(uint8_t row) { kb_Scan(); return row < 8 ? (uint8_t)kb_Data[row] : 0; }
uint8_t kb_AnyKey(void) { kb_Scan(); for(int i=0;i<8;i++) if(kb_Data[i]) return 1; return 0; }
void kb_Reset(void) { memset((void*)kb_Data,0,sizeof(kb_Data)); }
void kb_SetMode(uint8_t mode) { kb_mode=mode; (void)kb_mode; }
void kb_DisableOnLatch(void) { on_latch=0; }
void kb_ClearOnLatch(void) { on_latch=0; }
bool kb_On(void) { int v=on_latch; on_latch=0; return v!=0; }