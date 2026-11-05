static const char *_prompt_keyboard(const char *txt, int max)
{
    InputPromptView view = { txt, _prompt_buf, NULL, 0, 0, 0,
                             "Enter: confirm   Esc: cancel" };
    int len = 0;

    _prompt_buf[0] = 0;

    SDL_StartTextInput();
    SDL_FlushEvents(SDL_TEXTEDITING, SDL_TEXTINPUT);

    for (;;)
    {
        SDL_Event e;

        while (SDL_PollEvent(&e))
        {
            if (e.type == SDL_QUIT)
            {
                SDL_PushEvent(&e);
                goto cancel;
            }

            if (e.type == SDL_TEXTINPUT)
            {
                for (const char *c = e.text.text; *c; c++)
                {
                    unsigned char ch = (unsigned char)*c;

                    if (len < max && ch >= 32 && ch < 127)
                        _prompt_buf[len++] = *c;
                }

                _prompt_buf[len] = 0;
            }
            else if (e.type == SDL_KEYDOWN)
            {
                SDL_Keycode key = e.key.keysym.sym;

                if (key == SDLK_BACKSPACE && len > 0)
                    _prompt_buf[--len] = 0;
                else if (!e.key.repeat &&
                         (key == SDLK_RETURN || key == SDLK_KP_ENTER))
                {
                    SDL_StopTextInput();
                    return _prompt_buf;
                }
                else if (!e.key.repeat && key == SDLK_ESCAPE)
                    goto cancel;
            }
        }

        _prompt_draw(&view);
        SDL_Delay(16);
    }

cancel:
    SDL_StopTextInput();
    return NULL;
}

static bool _keyboard_any(void)
{
    int n = 0;
    const Uint8 *k = SDL_GetKeyboardState(&n);

    for (int i = 0; i < n; i++)
        if (k[i])
            return true;

    return false;
}