#include <string.h>
#include <stdbool.h>

#define PROMPT_COLS 10
#define PROMPT_ROWS 7

#ifndef GFX_LCD_WIDTH
#define GFX_LCD_WIDTH  320
#define GFX_LCD_HEIGHT 240
#endif

static uint8_t _prompt_fg = 0;
static uint8_t _prompt_bg = 255;

void TextPromptSetColors(uint8_t fg, uint8_t bg)
{
    _prompt_fg = fg;
    _prompt_bg = bg;
}

static uint8_t _rest_color = 0;
static uint8_t _rest_fg    = 0;
static uint8_t _rest_bg    = 255;
static uint8_t _rest_tp    = 255;

void TextPromptSetRestore(uint8_t color, uint8_t fg, uint8_t bg, uint8_t transparent)
{
    _rest_color = color;
    _rest_fg    = fg;
    _rest_bg    = bg;
    _rest_tp    = transparent;
}

static uint8_t _prompt_tp(void)
{
    uint8_t t = 255;

    while (t == _prompt_fg || t == _prompt_bg)
        t--;

    return t;
}

/* 70 characters = 10 x 7 */
static const char _prompt_chars[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789 .,!?-_'";

static char _prompt_buf[INPUT_PROMPT_MAX + 1];

typedef struct {
    const char *title;
    const char *text;     /* typed so far */
    const char *grid;     /* on-screen keyboard characters, NULL for a real keyboard */
    int cols, rows, sel;
    const char *hint;     /* control hints shown at the bottom */
} InputPromptView;

/* Draws and presents one frame of the prompt. */
static void _prompt_draw(const InputPromptView *v)
{
    const int cell_w = 28, cell_h = 18;
    int grid_x = (GFX_LCD_WIDTH - PROMPT_COLS * cell_w) / 2;
    int grid_y = 60;

    gfx_FillScreen(_prompt_bg);
    gfx_SetColor(_prompt_fg);
    gfx_SetTextFGColor(_prompt_fg);
    gfx_SetTextScale(1, 1);

    gfx_PrintStringXY(v->title, 10, 10);

    /* Text box with a caret after the typed text */
    gfx_Rectangle(8, 28, GFX_LCD_WIDTH - 16, 16);
    gfx_PrintStringXY(v->text, 12, 32);
    gfx_VertLine(12 + (int)strlen(v->text) * 8, 31, 10);

    if (v->grid)
    {
        for (int i = 0; i < v->cols * v->rows; i++)
        {
            char s[2] = { v->grid[i], 0 };
            int x = grid_x + (i % v->cols) * cell_w;
            int y = grid_y + (i / v->cols) * cell_h;

            if (i == v->sel)
                gfx_Rectangle(x, y, cell_w - 2, cell_h - 2);

            gfx_PrintStringXY(s, x + 10, y + 5);
        }
    }

    gfx_PrintStringXY(v->hint, 10, GFX_LCD_HEIGHT - 16);
    gfx_SwapDraw();
}

enum { PK_UP, PK_DOWN, PK_LEFT, PK_RIGHT, PK_OK, PK_DEL, PK_DONE, PK_CANCEL, PK_N };

/* Fills keys[] with the current state. Returns false if the app is quitting. */
typedef bool (*PromptPoll)(bool keys[PK_N]);

static void _prompt_move(int *sel, int dx, int dy)
{
    int col = (*sel % PROMPT_COLS + dx + PROMPT_COLS) % PROMPT_COLS;
    int row = (*sel / PROMPT_COLS + dy + PROMPT_ROWS) % PROMPT_ROWS;
    *sel = row * PROMPT_COLS + col;
}

/* On-screen keyboard shared by the calculator and gamepad. */
static const char *_prompt_osk(const char *txt, int max, const char *hint, PromptPoll poll)
{
    InputPromptView view = { txt, _prompt_buf, _prompt_chars,
                             PROMPT_COLS, PROMPT_ROWS, 0, hint };
    bool prev[PK_N], now[PK_N];
    int len = 0;

    _prompt_buf[0] = 0;

    /* Keys held on entry must be released before they count */
    poll(prev);

    for (;;)
    {
        if (!poll(now))
            return NULL;

        if (now[PK_UP]    && !prev[PK_UP])    _prompt_move(&view.sel,  0, -1);
        if (now[PK_DOWN]  && !prev[PK_DOWN])  _prompt_move(&view.sel,  0,  1);
        if (now[PK_LEFT]  && !prev[PK_LEFT])  _prompt_move(&view.sel, -1,  0);
        if (now[PK_RIGHT] && !prev[PK_RIGHT]) _prompt_move(&view.sel,  1,  0);

        if (now[PK_OK] && !prev[PK_OK] && len < max)
        {
            _prompt_buf[len++] = _prompt_chars[view.sel];
            _prompt_buf[len] = 0;
        }

        if (now[PK_DEL] && !prev[PK_DEL] && len > 0)
            _prompt_buf[--len] = 0;

        if (now[PK_DONE] && !prev[PK_DONE])
            return _prompt_buf;

        if (now[PK_CANCEL] && !prev[PK_CANCEL])
            return NULL;

        memcpy(prev, now, sizeof prev);
        _prompt_draw(&view);
    }
}