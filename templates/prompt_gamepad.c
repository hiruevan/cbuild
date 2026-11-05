static bool _prompt_pad_poll(bool k[PK_N])
{
    SDL_Event e;

    while (SDL_PollEvent(&e))
    {
        if (e.type == SDL_QUIT)
        {
            SDL_PushEvent(&e);   /* let the game see it too */
            return false;
        }
    }

    SDL_Delay(16);
    _pad_refresh();
    SDL_GameControllerUpdate();

    k[PK_UP]     = _pad_button(SDL_CONTROLLER_BUTTON_DPAD_UP)    || _pad_axis(SDL_CONTROLLER_AXIS_LEFTY, -1);
    k[PK_DOWN]   = _pad_button(SDL_CONTROLLER_BUTTON_DPAD_DOWN)  || _pad_axis(SDL_CONTROLLER_AXIS_LEFTY, +1);
    k[PK_LEFT]   = _pad_button(SDL_CONTROLLER_BUTTON_DPAD_LEFT)  || _pad_axis(SDL_CONTROLLER_AXIS_LEFTX, -1);
    k[PK_RIGHT]  = _pad_button(SDL_CONTROLLER_BUTTON_DPAD_RIGHT) || _pad_axis(SDL_CONTROLLER_AXIS_LEFTX, +1);
    k[PK_OK]     = _pad_button(SDL_CONTROLLER_BUTTON_A);
    k[PK_DEL]    = _pad_button(SDL_CONTROLLER_BUTTON_B);
    k[PK_DONE]   = _pad_button(SDL_CONTROLLER_BUTTON_START);
    k[PK_CANCEL] = _pad_button(SDL_CONTROLLER_BUTTON_BACK);

    return true;
}

static bool _pad_any(void)
{
    for (int i = 0; i < PAD_MAX; i++)
    {
        if (!_pads[i])
            continue;

        for (int b = 0; b < SDL_CONTROLLER_BUTTON_MAX; b++)
            if (SDL_GameControllerGetButton(_pads[i], (SDL_GameControllerButton)b))
                return true;
    }

    for (int a = 0; a < SDL_CONTROLLER_AXIS_MAX; a++)
        if (_pad_axis((SDL_GameControllerAxis)a, +1) ||
            _pad_axis((SDL_GameControllerAxis)a, -1))
            return true;

    return false;
}

static const char *_prompt_gamepad(const char *txt, int max)
{
    return _prompt_osk(txt, max, "A: type  B: erase  +: ok  -: cancel", _prompt_pad_poll);
}