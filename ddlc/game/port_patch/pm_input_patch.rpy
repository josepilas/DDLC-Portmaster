init -970 python:
    if not hasattr(renpy, "pm_native_input"):
        renpy.pm_native_input = renpy.input

    def pm_input(prompt="", default="", allow=None, exclude="{}", length=None, with_none=None, pixel_width=None, allow_empty=False):
        default = default or ""
        if length is None:
            length = 64

        if (pm_is_portmaster or pm_is_desktop_test) and PM_USE_VIRTUAL_KEYBOARD:
            value = pm_virtual_input(
                prompt=prompt,
                default=default,
                length=length,
                allow_empty=allow_empty,
                allowed=allow,
                exclude=exclude
            )
            if value is None:
                return default
            if not allow_empty and value == "":
                return default
            return value[:length]

        value = renpy.pm_native_input(
            prompt,
            default=default,
            allow=allow,
            exclude=exclude,
            length=length,
            with_none=with_none,
            pixel_width=pixel_width
        )
        if value is None:
            value = default
        if not allow_empty and value == "":
            value = default
        return value[:length]

    # Runtime patches install this as renpy.input so DDLC name entry can open
    # the controller-friendly keyboard without editing the original archives.
