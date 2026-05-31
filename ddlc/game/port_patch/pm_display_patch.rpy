init 2 python:
    def pm_parse_positive_int(value):
        try:
            parsed = int(str(value).strip())
        except Exception:
            return None

        if parsed <= 0:
            return None

        return parsed

    def pm_normalize_aspect_mode(value):
        mode = str(value or "auto").strip().lower().replace("x", ":")

        if mode in ("4:3", "four:three", "four-three", "standard"):
            return "4:3"

        if mode in ("16:9", "wide", "widescreen"):
            return "16:9"

        return "auto"

    def pm_read_screen_size_env():
        width = pm_parse_positive_int(os.environ.get("PM_SCREEN_WIDTH"))
        height = pm_parse_positive_int(os.environ.get("PM_SCREEN_HEIGHT"))
        return width, height

    def pm_detect_aspect_mode(width, height):
        forced_mode = pm_normalize_aspect_mode(os.environ.get("PM_ASPECT_MODE", "auto"))

        if forced_mode != "auto":
            return forced_mode

        if width and height:
            try:
                if (float(width) / float(height)) <= 1.45:
                    return "4:3"
            except Exception:
                pass
        elif PM_DEVICE_PROFILE in ("r36s", "r36h"):
            return "4:3"
        elif PM_DEVICE_PROFILE == "r36h_wide":
            return "16:9"

        return "16:9"

    def pm_display_size_for_mode(mode, width, height):
        if width and height:
            return width, height

        if PM_DEVICE_PROFILE in ("r36s", "r36h"):
            return PM_R36_FALLBACK_WIDTH, PM_R36_FALLBACK_HEIGHT

        if PM_DEVICE_PROFILE == "r36h_wide":
            return PM_BASE_VIRTUAL_WIDTH, PM_BASE_VIRTUAL_HEIGHT

        if mode == "4:3":
            return PM_FOUR_THREE_FALLBACK_WIDTH, PM_FOUR_THREE_FALLBACK_HEIGHT

        return PM_BASE_VIRTUAL_WIDTH, PM_BASE_VIRTUAL_HEIGHT

    def pm_env_flag_default(name, default_value):
        if name in os.environ:
            return pm_env_flag(name)

        return default_value

    def pm_stretch_adjust_view_size(width, height):
        return int(width), int(height)

    def pm_apply_display_mode():
        global pm_display_mode
        global pm_display_physical_size
        global pm_display_scale_mode
        global pm_display_fullscreen

        width, height = pm_read_screen_size_env()
        pm_display_mode = pm_detect_aspect_mode(width, height)
        pm_display_physical_size = pm_display_size_for_mode(pm_display_mode, width, height)
        pm_display_scale_mode = str(os.environ.get("PM_ASPECT_SCALE", "fit")).strip().lower()
        pm_display_fullscreen = pm_env_flag_default("PM_FULLSCREEN", pm_is_portmaster and not pm_is_desktop_test)

        config.screen_width = PM_BASE_VIRTUAL_WIDTH
        config.screen_height = PM_BASE_VIRTUAL_HEIGHT
        config.save_physical_size = False

        try:
            persistent._virtual_size = (PM_BASE_VIRTUAL_WIDTH, PM_BASE_VIRTUAL_HEIGHT)
        except Exception:
            pass

        try:
            renpy.game.preferences.virtual_size = (PM_BASE_VIRTUAL_WIDTH, PM_BASE_VIRTUAL_HEIGHT)
            renpy.game.preferences.physical_size = pm_display_physical_size
            renpy.game.preferences.fullscreen = pm_display_fullscreen
        except Exception as exc:
            pm_log("Could not apply display preferences: {0}".format(exc))

        if pm_display_mode == "4:3" and pm_display_scale_mode == "stretch":
            config.adjust_view_size = pm_stretch_adjust_view_size
        elif pm_display_mode == "4:3":
            config.adjust_view_size = None

        pm_log(
            "display mode={0} virtual={1}x{2} physical={3}x{4} scale={5} fullscreen={6}".format(
                pm_display_mode,
                PM_BASE_VIRTUAL_WIDTH,
                PM_BASE_VIRTUAL_HEIGHT,
                pm_display_physical_size[0],
                pm_display_physical_size[1],
                pm_display_scale_mode,
                pm_display_fullscreen,
            )
        )
        pm_log(
            "hardware profile={0} memory={1} screen_class={2} small_screen={3}".format(
                PM_DEVICE_PROFILE,
                PM_MEMORY_CLASS,
                PM_SCREEN_CLASS,
                PM_SMALL_SCREEN,
            )
        )

    pm_apply_display_mode()
