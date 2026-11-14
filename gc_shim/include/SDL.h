#ifndef CBUILD_GC_SDL_COMPAT_H
#define CBUILD_GC_SDL_COMPAT_H
#include <stdint.h>
typedef int SDL_bool;
typedef int SDL_GameControllerButton;
typedef int SDL_GameControllerAxis;
typedef int32_t SDL_JoystickID;
typedef struct SDL_GameController SDL_GameController;
typedef struct SDL_Joystick SDL_Joystick;
typedef struct { uint32_t type; } SDL_Event;
enum { SDL_INIT_GAMECONTROLLER=0x00002000, SDL_QUIT=0x100 };
enum {
 SDL_CONTROLLER_BUTTON_A, SDL_CONTROLLER_BUTTON_B, SDL_CONTROLLER_BUTTON_X,
 SDL_CONTROLLER_BUTTON_Y, SDL_CONTROLLER_BUTTON_BACK, SDL_CONTROLLER_BUTTON_GUIDE,
 SDL_CONTROLLER_BUTTON_START, SDL_CONTROLLER_BUTTON_LEFTSTICK, SDL_CONTROLLER_BUTTON_RIGHTSTICK,
 SDL_CONTROLLER_BUTTON_LEFTSHOULDER, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER,
 SDL_CONTROLLER_BUTTON_DPAD_UP, SDL_CONTROLLER_BUTTON_DPAD_DOWN,
 SDL_CONTROLLER_BUTTON_DPAD_LEFT, SDL_CONTROLLER_BUTTON_DPAD_RIGHT,
 SDL_CONTROLLER_BUTTON_MAX
};
enum {
 SDL_CONTROLLER_AXIS_LEFTX, SDL_CONTROLLER_AXIS_LEFTY,
 SDL_CONTROLLER_AXIS_RIGHTX, SDL_CONTROLLER_AXIS_RIGHTY,
 SDL_CONTROLLER_AXIS_TRIGGERLEFT, SDL_CONTROLLER_AXIS_TRIGGERRIGHT,
 SDL_CONTROLLER_AXIS_MAX
};
int SDL_InitSubSystem(uint32_t flags);
int SDL_NumJoysticks(void);
int SDL_IsGameController(int joystick_index);
SDL_JoystickID SDL_JoystickGetDeviceInstanceID(int joystick_index);
SDL_GameController *SDL_GameControllerOpen(int joystick_index);
int SDL_GameControllerGetAttached(SDL_GameController *controller);
void SDL_GameControllerClose(SDL_GameController *controller);
SDL_Joystick *SDL_GameControllerGetJoystick(SDL_GameController *controller);
SDL_JoystickID SDL_JoystickInstanceID(SDL_Joystick *joystick);
void SDL_GameControllerUpdate(void);
int SDL_GameControllerGetButton(SDL_GameController *controller,SDL_GameControllerButton button);
int16_t SDL_GameControllerGetAxis(SDL_GameController *controller,SDL_GameControllerAxis axis);
int SDL_PollEvent(SDL_Event *event);
int SDL_PushEvent(SDL_Event *event);
void SDL_Delay(uint32_t ms);
#endif
