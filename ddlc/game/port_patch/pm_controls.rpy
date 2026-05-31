init -965 python:
    def pm_open_quick_panel_context():
        try:
            renpy.call_in_new_context("pm_open_quick_panel")
        except Exception as exc:
            pm_log("Could not open quick panel: {0}".format(exc))

    def pm_add_keymap(name, keys):
        if name not in config.keymap:
            config.keymap[name] = []
        for key in keys:
            if key not in config.keymap[name]:
                config.keymap[name].append(key)

    pm_add_keymap("dismiss", ["K_z"])
    pm_add_keymap("button_select", ["K_z"])
    pm_add_keymap("focus_left", ["K_a"])
    pm_add_keymap("focus_right", ["K_d"])
    pm_add_keymap("focus_up", ["K_w"])
    pm_add_keymap("focus_down", ["K_s"])
    pm_add_keymap("pm_file_manager", ["K_F10"])
    pm_add_keymap("pm_quick_panel", ["K_F9"])
    pm_add_keymap("game_menu", ["K_ESCAPE"])
    pm_add_keymap("rollback", ["K_PAGEUP"])
    pm_add_keymap("rollforward", ["K_PAGEDOWN"])
    pm_add_keymap("hide_windows", ["K_h"])
    pm_add_keymap("toggle_afm", ["K_F8"])
    pm_add_keymap("toggle_skip", ["K_F7"])

    try:
        config.underlay.append(renpy.Keymap(
            pm_file_manager=Function(pm_open_file_manager_context),
            pm_quick_panel=Function(pm_open_quick_panel_context)
        ))
    except Exception as exc:
        pm_log("Could not install PortMaster keymap: {0}".format(exc))

    try:
        renpy.display.behavior.clear_keymap_cache()
    except Exception:
        pass

    # Existing DDLC/Ren'Py navigation stays in place; these additions give
    # gptokeyb and keyboards stable handheld-focused entry points.
