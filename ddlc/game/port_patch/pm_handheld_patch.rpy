init 1002 python:
    def pm_text_setting(name, default_value):
        value = os.environ.get(name, default_value)
        return str(value or default_value).strip().lower()

    def pm_can_show_save_menu():
        return not globals().get("main_menu", False) and not globals().get("_in_replay", False)

    def pm_can_show_load_menu():
        return not globals().get("_in_replay", False)

    pm_handheld_mode = pm_env_flag_default("PM_HANDHELD_MODE", pm_is_portmaster or pm_is_desktop_test)
    pm_show_touch_quick_menu = pm_env_flag_default("PM_SHOW_TOUCH_QUICK_MENU", not pm_handheld_mode)

    if pm_handheld_mode:
        quick_menu = pm_show_touch_quick_menu

        try:
            renpy.game.preferences.pad_enabled = pm_env_flag_default("PM_ENABLE_RENPY_PAD", True)
        except Exception as exc:
            pm_log("Could not enable Ren'Py pad preference: {0}".format(exc))

        if PM_PERFORMANCE_PROFILE == "low":
            config.image_cache_size = 32
            config.predict_statements = 20
        elif PM_PERFORMANCE_PROFILE == "quality":
            config.image_cache_size = 96
            config.predict_statements = 75
        elif PM_DEVICE_PROFILE in ("r36s", "r36h", "r36h_wide", "rk3326"):
            config.image_cache_size = 48
            config.predict_statements = 28

        if PM_IMAGE_CACHE_SIZE is not None:
            config.image_cache_size = PM_IMAGE_CACHE_SIZE

        if PM_PREDICT_STATEMENTS is not None:
            config.predict_statements = PM_PREDICT_STATEMENTS

        if PM_FRAMERATE is not None:
            config.framerate = PM_FRAMERATE

        try:
            if PM_GL_FRAMERATE is not None:
                renpy.game.preferences.gl_framerate = PM_GL_FRAMERATE
            renpy.game.preferences.gl_powersave = PM_GL_POWERSAVE
        except Exception as exc:
            pm_log("Could not apply GL performance preferences: {0}".format(exc))

        pm_log(
            "handheld mode={0} touch_quick_menu={1} performance={2} image_cache={3} predict={4} framerate={5} gl_framerate={6}".format(
                pm_handheld_mode,
                pm_show_touch_quick_menu,
                PM_PERFORMANCE_PROFILE,
                config.image_cache_size,
                config.predict_statements,
                config.framerate,
                getattr(renpy.game.preferences, "gl_framerate", None),
            )
        )

label pm_open_quick_panel:
    call screen pm_quick_panel
    return

screen pm_quick_panel():
    modal True
    tag pm_quick_panel
    zorder 250

    key "K_ESCAPE" action Return()
    key "K_F9" action Return()
    key "K_BACKSPACE" action Return()

    add Solid("#00000099")

    frame:
        background "#101820"
        xalign 0.5
        yalign 0.5
        xmaximum 930
        padding (22, 20)

        vbox:
            spacing 14
            xfill True

            text "Quick Panel" color "#ffffff" size 30 xalign 0.5

            grid 2 4:
                spacing 10
                xalign 0.5

                textbutton "History":
                    xminimum 405
                    yminimum 62
                    action [Hide("pm_quick_panel"), ShowMenu("history")]

                textbutton "Settings":
                    xminimum 405
                    yminimum 62
                    action [Hide("pm_quick_panel"), ShowMenu("preferences")]

                textbutton "Save":
                    xminimum 405
                    yminimum 62
                    sensitive pm_can_show_save_menu()
                    action [Hide("pm_quick_panel"), ShowMenu("save")]

                textbutton "Load":
                    xminimum 405
                    yminimum 62
                    sensitive pm_can_show_load_menu()
                    action [Hide("pm_quick_panel"), ShowMenu("load")]

                textbutton "Auto":
                    xminimum 405
                    yminimum 62
                    action [Preference("auto-forward", "toggle"), Return()]

                textbutton "Skip":
                    xminimum 405
                    yminimum 62
                    action [Skip(), Return()]

                textbutton "Files":
                    xminimum 405
                    yminimum 62
                    action [Hide("pm_quick_panel"), Function(pm_open_file_manager_context)]

                textbutton "Close":
                    xminimum 405
                    yminimum 62
                    action Return()
