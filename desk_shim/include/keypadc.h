#ifndef CE_SHIM_KEYPADC_H
#define CE_SHIM_KEYPADC_H

#include <stdint.h>
#include <stdbool.h>
#include <tice.h>

#ifdef __cplusplus
extern "C" {
#endif

extern volatile uint16_t kb_Data[8];

typedef enum {
    kb_KeyGraph = 0x0101, kb_KeyTrace = 0x0102, kb_KeyZoom = 0x0104, kb_KeyWindow = 0x0108,
    kb_KeyYequ = 0x0110, kb_Key2nd = 0x0120, kb_KeyMode = 0x0140, kb_KeyDel = 0x0180,
    kb_KeySto = 0x0202, kb_KeyLn = 0x0204, kb_KeyLog = 0x0208, kb_KeySquare = 0x0210,
    kb_KeyRecip = 0x0220, kb_KeyMath = 0x0240, kb_KeyAlpha = 0x0280,
    kb_Key0 = 0x0301, kb_Key1 = 0x0302, kb_Key4 = 0x0304, kb_Key7 = 0x0308,
    kb_KeyComma = 0x0310, kb_KeySin = 0x0320, kb_KeyApps = 0x0340, kb_KeyGraphVar = 0x0380,
    kb_KeyDecPnt = 0x0401, kb_Key2 = 0x0402, kb_Key5 = 0x0404, kb_Key8 = 0x0408,
    kb_KeyLParen = 0x0410, kb_KeyCos = 0x0420, kb_KeyPrgm = 0x0440, kb_KeyStat = 0x0480,
    kb_KeyChs = 0x0501, kb_Key3 = 0x0502, kb_Key6 = 0x0504, kb_Key9 = 0x0508,
    kb_KeyRParen = 0x0510, kb_KeyTan = 0x0520, kb_KeyVars = 0x0540,
    kb_KeyEnter = 0x0601, kb_KeyAdd = 0x0602, kb_KeySub = 0x0604, kb_KeyMul = 0x0608,
    kb_KeyDiv = 0x0610, kb_KeyPower = 0x0620, kb_KeyClear = 0x0640,
    kb_KeyDown = 0x0701, kb_KeyLeft = 0x0702, kb_KeyRight = 0x0704, kb_KeyUp = 0x0708
} kb_lkey_t;

typedef enum {
    kb_group_1 = 1, kb_group_2, kb_group_3, kb_group_4, kb_group_5, kb_group_6, kb_group_7
} kb_group_t;

#define kb_Graph 0x01
#define kb_Trace 0x02
#define kb_Zoom 0x04
#define kb_Window 0x08
#define kb_Yequ 0x10
#define kb_2nd 0x20
#define kb_Mode 0x40
#define kb_Del 0x80
#define kb_Sto 0x02
#define kb_Ln 0x04
#define kb_Log 0x08
#define kb_Square 0x10
#define kb_Recip 0x20
#define kb_Math 0x40
#define kb_Alpha 0x80
#define kb_0 0x01
#define kb_1 0x02
#define kb_4 0x04
#define kb_7 0x08
#define kb_Comma 0x10
#define kb_Sin 0x20
#define kb_Apps 0x40
#define kb_GraphVar 0x80
#define kb_DecPnt 0x01
#define kb_2 0x02
#define kb_5 0x04
#define kb_8 0x08
#define kb_LParen 0x10
#define kb_Cos 0x20
#define kb_Prgm 0x40
#define kb_Stat 0x80
#define kb_Chs 0x01
#define kb_3 0x02
#define kb_6 0x04
#define kb_9 0x08
#define kb_RParen 0x10
#define kb_Tan 0x20
#define kb_Vars 0x40
#define kb_Enter 0x01
#define kb_Add 0x02
#define kb_Sub 0x04
#define kb_Mul 0x08
#define kb_Div 0x10
#define kb_Power 0x20
#define kb_Clear 0x40
#define kb_Down 0x01
#define kb_Left 0x02
#define kb_Right 0x04
#define kb_Up 0x08

#define kb_IsDown(key) ((kb_Data[((key) >> 8) & 7] & ((key) & 0xFF)) ? 1 : 0)

typedef enum { MODE_0_IDLE = 0, MODE_1_INDIRECT, MODE_2_SINGLE, MODE_3_CONTINUOUS } kb_mode_t;

void kb_Scan(void);
uint8_t kb_ScanGroup(uint8_t row);
uint8_t kb_AnyKey(void);
void kb_Reset(void);
void kb_SetMode(uint8_t mode);
void kb_DisableOnLatch(void);
void kb_ClearOnLatch(void);
bool kb_On(void);

#ifdef __cplusplus
}
#endif

#endif
