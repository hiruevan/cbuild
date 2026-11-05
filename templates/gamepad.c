#define PAD_MAX               4
#define PAD_STICK_THRESHOLD   16000   /* of 32767 */
#define PAD_TRIGGER_THRESHOLD 8000

static SDL_GameController *_pads[PAD_MAX];
static bool _pad_ready = false;

/* Opens newly connected controllers and drops disconnected ones. */
static void _pad_refresh(void)
{
    if (!_pad_ready)
    {
        SDL_InitSubSystem(SDL_INIT_GAMECONTROLLER);
        _pad_ready = true;
    }

    for (int i = 0; i < PAD_MAX; i++)
    {
        if (_pads[i] && !SDL_GameControllerGetAttached(_pads[i]))
        {
            SDL_GameControllerClose(_pads[i]);
            _pads[i] = NULL;
        }
    }

    int count = SDL_NumJoysticks();

    for (int dev = 0; dev < count; dev++)
    {
        if (!SDL_IsGameController(dev))
            continue;

        SDL_JoystickID id = SDL_JoystickGetDeviceInstanceID(dev);
        bool known = false;
        int free_slot = -1;

        for (int i = 0; i < PAD_MAX; i++)
        {
            if (!_pads[i])
            {
                if (free_slot < 0)
                    free_slot = i;
            }
            else if (SDL_JoystickInstanceID(
                         SDL_GameControllerGetJoystick(_pads[i])) == id)
            {
                known = true;
            }
        }

        if (!known && free_slot >= 0)
            _pads[free_slot] = SDL_GameControllerOpen(dev);
    }
}

/* True if the button is held on any connected controller. */
static bool _pad_button(SDL_GameControllerButton button)
{
    for (int i = 0; i < PAD_MAX; i++)
        if (_pads[i] && SDL_GameControllerGetButton(_pads[i], button))
            return true;

    return false;
}

/* True if the axis is pushed past its threshold in the given direction. */
static bool _pad_axis(SDL_GameControllerAxis axis, int sign)
{
    int threshold =
        (axis == SDL_CONTROLLER_AXIS_TRIGGERLEFT ||
         axis == SDL_CONTROLLER_AXIS_TRIGGERRIGHT)
            ? PAD_TRIGGER_THRESHOLD
            : PAD_STICK_THRESHOLD;

    for (int i = 0; i < PAD_MAX; i++)
    {
        if (!_pads[i])
            continue;

        int value = SDL_GameControllerGetAxis(_pads[i], axis);

        if (sign > 0 ? value > threshold : value < -threshold)
            return true;
    }

    return false;
}