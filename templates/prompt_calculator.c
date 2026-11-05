static bool _prompt_cal_poll(bool k[PK_N])
{
    kb_Scan();

    k[PK_UP]     = kb_IsDown(kb_KeyUp);
    k[PK_DOWN]   = kb_IsDown(kb_KeyDown);
    k[PK_LEFT]   = kb_IsDown(kb_KeyLeft);
    k[PK_RIGHT]  = kb_IsDown(kb_KeyRight);
    k[PK_OK]     = kb_IsDown(kb_Key2nd);
    k[PK_DEL]    = kb_IsDown(kb_KeyDel);
    k[PK_DONE]   = kb_IsDown(kb_KeyEnter);
    k[PK_CANCEL] = kb_IsDown(kb_KeyClear);

    return true;
}

static const char *_prompt_calculator(const char *txt, int max)
{
    return _prompt_osk(txt, max, "2nd: type  Del: erase  Enter: ok  Clear: quit",
                       _prompt_cal_poll);
}