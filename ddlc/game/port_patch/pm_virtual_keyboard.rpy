init -975 python:
    PM_VK_ROWS_LOWER = (
        "qwertyuiop",
        "asdfghjkl",
        "zxcvbnm",
        "1234567890",
        "._-",
    )

    PM_VK_ROWS_UPPER = (
        "QWERTYUIOP",
        "ASDFGHJKL",
        "ZXCVBNM",
        "1234567890",
        "._-",
    )

    def pm_vk_rows(uppercase):
        if uppercase:
            return PM_VK_ROWS_UPPER
        return PM_VK_ROWS_LOWER

    def pm_vk_insert_value(current, char, length):
        current = current or ""
        if len(current) >= length:
            return current
        return current + char

    def pm_vk_backspace_value(current):
        current = current or ""
        return current[:-1]

    def pm_vk_space_value(current, length):
        return pm_vk_insert_value(current, " ", length)

    def pm_vk_toggle_case_flag(uppercase):
        return not uppercase

    def pm_vk_can_confirm(current, allow_empty):
        return allow_empty or len(current or "") > 0

    def pm_vk_char_allowed(char, allowed=None, exclude=""):
        if allowed is not None and char not in allowed:
            return False
        if exclude is not None and char in exclude:
            return False
        return True

    def pm_vk_filter_value(value, length, allowed=None, exclude=""):
        result = ""
        for ch in value or "":
            if pm_vk_char_allowed(ch, allowed, exclude):
                result += ch
            if len(result) >= length:
                break
        return result

    def pm_vk_insert_filtered_value(current, char, length, allowed=None, exclude=""):
        current = pm_vk_filter_value(current, length, allowed, exclude)
        if len(current) >= length:
            return current
        if not pm_vk_char_allowed(char, allowed, exclude):
            return current
        return current + char

    def pm_virtual_input(prompt="", default="", length=16, allow_empty=False, allowed=None, exclude=""):
        value = renpy.call_screen(
            "pm_virtual_keyboard",
            prompt=prompt,
            default=default,
            length=length,
            allow_empty=allow_empty,
            allowed=allowed,
            exclude=exclude
        )
        if value is None:
            return None
        return pm_vk_filter_value(value, length, allowed, exclude)

screen pm_virtual_keyboard(prompt="", default="", length=16, allow_empty=False, allowed=None, exclude=""):
    modal True
    tag pm_virtual_keyboard
    default text_value = pm_vk_filter_value(default, length, allowed, exclude)
    default uppercase = False

    key "K_BACKSPACE" action SetScreenVariable("text_value", pm_vk_backspace_value(text_value))
    key "K_DELETE" action SetScreenVariable("text_value", pm_vk_backspace_value(text_value))
    key "K_ESCAPE" action If(pm_vk_can_confirm(text_value, allow_empty), Return(text_value), NullAction())
    key "K_TAB" action Return(None)
    key "K_F9" action Return(None)
    key "K_RETURN" action If(pm_vk_can_confirm(text_value, allow_empty), Return(text_value), NullAction())
    key "K_KP_ENTER" action If(pm_vk_can_confirm(text_value, allow_empty), Return(text_value), NullAction())
    key "K_SPACE" action SetScreenVariable("text_value", pm_vk_insert_filtered_value(text_value, " ", length, allowed, exclude))
    key "K_F10" action SetScreenVariable("text_value", pm_vk_insert_filtered_value(text_value, " ", length, allowed, exclude))
    key "K_h" action SetScreenVariable("uppercase", pm_vk_toggle_case_flag(uppercase))

    frame:
        background "#101820"
        xalign 0.5
        yalign 0.5
        xmaximum 980
        padding (22, 20)

        vbox:
            spacing 14
            xfill True

            if prompt:
                text prompt color "#ffffff" size 26 xalign 0.5

            frame:
                background "#ffffff"
                xfill True
                padding (14, 10)
                text "[text_value]_" color "#111111" size 30 xalign 0.5

            for row in pm_vk_rows(uppercase):
                hbox:
                    spacing 8
                    xalign 0.5
                    for ch in row:
                        textbutton ch:
                            xminimum 66
                            yminimum 52
                            sensitive pm_vk_char_allowed(ch, allowed, exclude)
                            action SetScreenVariable("text_value", pm_vk_insert_filtered_value(text_value, ch, length, allowed, exclude))

            hbox:
                spacing 10
                xalign 0.5
                textbutton "Space":
                    xminimum 145
                    yminimum 52
                    sensitive pm_vk_char_allowed(" ", allowed, exclude)
                    action SetScreenVariable("text_value", pm_vk_insert_filtered_value(text_value, " ", length, allowed, exclude))
                textbutton "Delete":
                    xminimum 125
                    yminimum 52
                    action SetScreenVariable("text_value", pm_vk_backspace_value(text_value))
                textbutton "Case":
                    xminimum 105
                    yminimum 52
                    action SetScreenVariable("uppercase", pm_vk_toggle_case_flag(uppercase))
                textbutton "OK":
                    xminimum 105
                    yminimum 52
                    sensitive pm_vk_can_confirm(text_value, allow_empty)
                    action Return(text_value)
                textbutton "Cancel":
                    xminimum 120
                    yminimum 52
                    action Return(None)
