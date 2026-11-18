#include <ogc/pad.h>
#include <ogc/system.h>
#include <ogc/video.h>
#include <ogc/irq.h>
#include <ogc/lwp_watchdog.h>
#include <string.h>
#include "SDL.h"

/*
 * Minimal SDL_GameController emulation on top of libogc's PAD API.
 *
 * Sampling model
 * --------------
 * The pad is sampled from the vertical-retrace interrupt (60 Hz / per field),
 * which is how libogc expects PAD_ScanPads() to be used. Each sample is
 * accumulated into a latch. SDL_GameControllerUpdate() (called once per
 * Input_Scan) takes a snapshot of everything that was pressed at ANY sample
 * since the previous Update (or the current state if there was none).
 *
 * This makes input independent of the game's frame rate: a quick D-pad or
 * stick tap that starts and ends between two game frames is still seen for
 * one frame instead of being lost, and a held input stays held. A release is
 * seen on the first frame after it happens, with no extra delay.
 *
 * Joystick indices 0..n-1 refer to the *connected* GameCube pads in port
 * order, so a controller in port 2 works the same as one in port 1. The
 * instance id of a pad is its port number + 1.
 */

struct SDL_Joystick { int port; };
struct SDL_GameController { int port; int open; struct SDL_Joystick joy; };

static struct SDL_GameController controllers[4];   /* indexed by port */
static int initialized;

/* ---- raw sampling (runs in the retrace interrupt) --------------------- */

typedef struct {
    int16_t x, y, cx, cy;        /* libogc units: +X right, +Y up */
    uint8_t tl, tr;
    uint16_t btn;
} PadSample;

typedef struct {
    uint16_t btn;
    int16_t  xmax, xmin, ymax, ymin, cxmax, cxmin, cymax, cymin;
    uint8_t  tlmax, trmax;
    uint8_t  n;                  /* samples accumulated since the last snapshot */
} PadLatch;

static volatile uint32_t pad_mask;                 /* ports currently considered connected */
static uint8_t  pad_miss[4];                       /* consecutive scans a seen port was missing */
static PadSample cur[4];                           /* most recent sample */
static PadLatch  latch[4];                         /* accumulated since last snapshot */
static PadSample snap[4];                          /* what the game sees until the next Update */
static volatile uint32_t sample_count;

/*
 * PAD_ScanPads() only reports a port when that particular read succeeded.
 * libogc returns PAD_ERR_TRANSFER (port missing from the mask) whenever there
 * is no fresh controller sample since the previous read. libogc keeps the last
 * good state through those reads and clears it only when the pad is really
 * unplugged, so a port stays "connected" through short dropouts.
 */
#define PAD_DROPOUT_SCANS 90

static inline int16_t imax(int16_t a, int16_t b) { return a > b ? a : b; }
static inline int16_t imin(int16_t a, int16_t b) { return a < b ? a : b; }

static void pad_sample(void)
{
    uint32_t seen = PAD_ScanPads();
    uint32_t mask = pad_mask;

    for (int p = 0; p < 4; p++) {
        if (seen & (1u << p)) {
            mask |= (1u << p);
            pad_miss[p] = 0;
        } else if (mask & (1u << p)) {
            if (++pad_miss[p] >= PAD_DROPOUT_SCANS) {
                mask &= ~(1u << p);
                pad_miss[p] = 0;
            }
        }

        /* libogc returns zeros for ports with no controller, so always read. */
        PadSample *c = &cur[p];
        c->btn = PAD_ButtonsHeld(p);
        c->x  = PAD_StickX(p);     c->y  = PAD_StickY(p);
        c->cx = PAD_SubStickX(p);  c->cy = PAD_SubStickY(p);
        c->tl = PAD_TriggerL(p);   c->tr = PAD_TriggerR(p);

        PadLatch *l = &latch[p];
        if (l->n == 0) {
            l->btn = c->btn;
            l->xmax = l->xmin = c->x;    l->ymax = l->ymin = c->y;
            l->cxmax = l->cxmin = c->cx; l->cymax = l->cymin = c->cy;
            l->tlmax = c->tl;            l->trmax = c->tr;
        } else {
            l->btn |= c->btn;
            l->xmax = imax(l->xmax, c->x);   l->xmin = imin(l->xmin, c->x);
            l->ymax = imax(l->ymax, c->y);   l->ymin = imin(l->ymin, c->y);
            l->cxmax = imax(l->cxmax, c->cx); l->cxmin = imin(l->cxmin, c->cx);
            l->cymax = imax(l->cymax, c->cy); l->cymin = imin(l->cymin, c->cy);
            if (c->tl > l->tlmax) l->tlmax = c->tl;
            if (c->tr > l->trmax) l->trmax = c->tr;
        }
        if (l->n < 255) l->n++;
    }

    pad_mask = mask;
    sample_count++;
}

static void retrace_cb(uint32_t retrace_count)
{
    (void)retrace_count;
    pad_sample();
}

/* The extreme with the larger magnitude, so a tap in either direction survives. */
static int16_t extreme(int16_t hi, int16_t lo) { return hi >= -lo ? hi : lo; }

static void pad_snapshot(void)
{
    uint32_t level = IRQ_Disable();

    for (int p = 0; p < 4; p++) {
        PadLatch *l = &latch[p];
        const PadSample *c = &cur[p];

        if (l->n == 0) {
            /* No sample since the last snapshot: the current state is all there is. */
            snap[p] = *c;
        } else {
            snap[p].btn = l->btn;
            snap[p].x  = extreme(l->xmax, l->xmin);    snap[p].y  = extreme(l->ymax, l->ymin);
            snap[p].cx = extreme(l->cxmax, l->cxmin);  snap[p].cy = extreme(l->cymax, l->cymin);
            snap[p].tl = l->tlmax;  snap[p].tr = l->trmax;
        }
        l->n = 0;     /* only samples taken from now on count for the next frame */
    }

    IRQ_Restore(level);
}

/* GameCube sticks report roughly +/-80..100 at full throw; SDL expects +/-32767. */
#define STICK_SCALE 410

static int16_t stick_axis(int v)
{
    int r = v * STICK_SCALE;
    if (r >  32767) r =  32767;
    if (r < -32767) r = -32767;
    return (int16_t)r;
}

static int port_from_index(int index)
{
    int n = 0;
    uint32_t mask = pad_mask;
    if (index < 0) return -1;
    for (int p = 0; p < 4; p++) {
        if (mask & (1u << p)) {
            if (n == index) return p;
            n++;
        }
    }
    return -1;
}

int SDL_InitSubSystem(uint32_t flags)
{
    (void)flags;
    PAD_Init();
    pad_mask = 0;
    memset(pad_miss, 0, sizeof pad_miss);
    memset(cur, 0, sizeof cur);
    memset(latch, 0, sizeof latch);
    memset(snap, 0, sizeof snap);
    sample_count = 0;
    pad_sample();                                   /* initial read, before the callback exists */
    VIDEO_SetPostRetraceCallback(retrace_cb);       /* from now on: one sample per retrace */
    initialized = 1;
    return 0;
}

int SDL_NumJoysticks(void)
{
    int n = 0;
    uint32_t mask;
    if (!initialized) SDL_InitSubSystem(0);
    mask = pad_mask;
    for (int p = 0; p < 4; p++)
        if (mask & (1u << p)) n++;
    return n;
}

int SDL_IsGameController(int i) { return port_from_index(i) >= 0; }

SDL_JoystickID SDL_JoystickGetDeviceInstanceID(int i)
{
    int p = port_from_index(i);
    return p >= 0 ? p + 1 : -1;
}

SDL_GameController *SDL_GameControllerOpen(int i)
{
    int p = port_from_index(i);
    if (p < 0) return 0;
    controllers[p].port = p;
    controllers[p].open = 1;
    controllers[p].joy.port = p;
    return &controllers[p];
}

int SDL_GameControllerGetAttached(SDL_GameController *c)
{
    return c && c->open && (pad_mask & (1u << c->port));
}

void SDL_GameControllerClose(SDL_GameController *c) { if (c) c->open = 0; }
SDL_Joystick *SDL_GameControllerGetJoystick(SDL_GameController *c) { return c ? &c->joy : 0; }
SDL_JoystickID SDL_JoystickInstanceID(SDL_Joystick *j) { return j ? j->port + 1 : -1; }

void SDL_GameControllerUpdate(void)
{
    static int fallback_updates;
    if (!initialized) SDL_InitSubSystem(0);

    /*
     * If the retrace callback never fires (video not initialised yet), fall
     * back to sampling here so input still works.
     */
    if (sample_count <= 1 && ++fallback_updates > 2)
        pad_sample();

    pad_snapshot();
}

int SDL_GameControllerGetButton(SDL_GameController *c, SDL_GameControllerButton b)
{
    if (!c || !c->open) return 0;
    uint16_t v = snap[c->port].btn;
    switch (b) {
      case SDL_CONTROLLER_BUTTON_A: return !!(v & PAD_BUTTON_A);
      case SDL_CONTROLLER_BUTTON_B: return !!(v & PAD_BUTTON_B);
      case SDL_CONTROLLER_BUTTON_X: return !!(v & PAD_BUTTON_X);
      case SDL_CONTROLLER_BUTTON_Y: return !!(v & PAD_BUTTON_Y);
      case SDL_CONTROLLER_BUTTON_BACK: return !!(v & PAD_TRIGGER_Z);
      case SDL_CONTROLLER_BUTTON_START: return !!(v & PAD_BUTTON_START);
      case SDL_CONTROLLER_BUTTON_LEFTSHOULDER: return !!(v & PAD_TRIGGER_L);
      case SDL_CONTROLLER_BUTTON_RIGHTSHOULDER: return !!(v & PAD_TRIGGER_R);
      case SDL_CONTROLLER_BUTTON_DPAD_UP: return !!(v & PAD_BUTTON_UP);
      case SDL_CONTROLLER_BUTTON_DPAD_DOWN: return !!(v & PAD_BUTTON_DOWN);
      case SDL_CONTROLLER_BUTTON_DPAD_LEFT: return !!(v & PAD_BUTTON_LEFT);
      case SDL_CONTROLLER_BUTTON_DPAD_RIGHT: return !!(v & PAD_BUTTON_RIGHT);
      case SDL_CONTROLLER_BUTTON_LEFTSTICK: return 0;
      case SDL_CONTROLLER_BUTTON_RIGHTSTICK: return 0;
      case SDL_CONTROLLER_BUTTON_GUIDE: return 0;
      default: return 0;
    }
}

int16_t SDL_GameControllerGetAxis(SDL_GameController *c, SDL_GameControllerAxis a)
{
    if (!c || !c->open) return 0;
    const PadSample *s = &snap[c->port];
    switch (a) {
      /* SDL's Y axes grow downward; libogc's grow upward. */
      case SDL_CONTROLLER_AXIS_LEFTX: return stick_axis(s->x);
      case SDL_CONTROLLER_AXIS_LEFTY: return stick_axis(-s->y);
      case SDL_CONTROLLER_AXIS_RIGHTX: return stick_axis(s->cx);
      case SDL_CONTROLLER_AXIS_RIGHTY: return stick_axis(-s->cy);
      case SDL_CONTROLLER_AXIS_TRIGGERLEFT: return (int16_t)(s->tl * 128);
      /* ZR is the GameCube Z button (digital, so full scale when held).
         The analog R trigger is still reachable as the RIGHTSHOULDER button. */
      case SDL_CONTROLLER_AXIS_TRIGGERRIGHT: return (s->btn & PAD_TRIGGER_Z) ? 32767 : 0;
      default: return 0;
    }
}

int SDL_PollEvent(SDL_Event *e) { (void)e; return 0; }
int SDL_PushEvent(SDL_Event *e) { (void)e; return 0; }

void SDL_Delay(uint32_t ms)
{
    /*
     * Shared code uses SDL_Delay(16) as per-frame pacing. On this target every
     * SwapDraw()/Wait() already blocks until vblank, so honouring that
     * delay too would stack a second frame of latency onto every loop
     * iteration. Longer delays are real waits and are honoured.
     */
    if (ms <= 16) return;
    udelay(ms * 1000);
}