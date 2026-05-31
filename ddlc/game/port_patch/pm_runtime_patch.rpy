init 1000 python:
    import os
    import __builtin__

    def pm_character_from_path(path):
        if path is None:
            return None
        value = str(path).replace("\\", "/").lower()
        for name in PM_VALID_CHARACTERS:
            if value.endswith("/characters/{0}.chr".format(name)):
                return name
            if value == "../characters/{0}.chr".format(name):
                return name
            if value == "characters/{0}.chr".format(name):
                return name
        return None

    def pm_original_character_path(name):
        normalized = pm_normalize_character_name(name)
        if normalized is None:
            return None
        return os.path.join(pm_original_dir, "characters", normalized + ".chr")

    if not hasattr(renpy, "pm_original_file"):
        renpy.pm_original_file = renpy.file

    def pm_file(path, *args, **kwargs):
        char_name = pm_character_from_path(path)
        if char_name:
            if not pm_character_exists(char_name):
                raise IOError("Virtual character file is missing: {0}.chr".format(char_name))

            real_path = pm_original_character_path(char_name)
            if real_path and os.path.isfile(real_path):
                return __builtin__.open(real_path, "rb")

        return renpy.pm_original_file(path, *args, **kwargs)

    renpy.file = pm_file

    class PMNullWriteFile(object):
        def write(self, data):
            try:
                return len(data)
            except Exception:
                return None

        def flush(self):
            return None

        def close(self):
            return None

        def __enter__(self):
            return self

        def __exit__(self, exc_type, exc_value, traceback):
            self.close()
            return False

    if not hasattr(__builtin__, "pm_original_open"):
        __builtin__.pm_original_open = __builtin__.open

    def pm_open(path, mode="r", *args, **kwargs):
        char_name = pm_character_from_path(path)
        if char_name and ("w" in mode or "a" in mode or "+" in mode):
            pm_restore_character(char_name)
            pm_log("Suppressed real character write: {0}".format(path))
            return PMNullWriteFile()
        return __builtin__.pm_original_open(path, mode, *args, **kwargs)

    __builtin__.open = pm_open

    def delete_character(name):
        return pm_delete_character(name)

    def restore_all_characters():
        return pm_restore_all_characters()

    def restore_relevant_characters():
        pm_restore_all_characters()
        playthrough = getattr(persistent, "playthrough", 0) or 0

        if playthrough == 1 or playthrough == 2:
            pm_delete_character("sayori")
        elif playthrough == 3:
            pm_delete_character("sayori")
            pm_delete_character("natsuki")
            pm_delete_character("yuri")
        elif playthrough == 4:
            pm_delete_character("monika")

    renpy.input = pm_input
    pm_log("Runtime compatibility patches installed")

init 1001 python:
    def pm_name_input_keyboard_action(ok_action, message):
        renpy.call_in_new_context("pm_name_input_keyboard_context", ok_action, message)

label pm_name_input_keyboard_context(ok_action, message):
    $ typed_name = pm_virtual_input(prompt=message, default=player, length=12, allow_empty=False, allowed=PM_NAME_ALLOWED_CHARS)
    if typed_name:
        $ player = typed_name
        $ persistent.playername = typed_name
        $ renpy.save_persistent()
        $ renpy.hide_screen("name_input")
        $ renpy.jump_out_of_context("start")
    return

init 1001 screen name_input(message, ok_action):
    modal True
    zorder 200
    style_prefix "confirm"
    add "gui/overlay/confirm.png"

    key "K_RETURN" action Function(pm_name_input_keyboard_action, ok_action, message)
    timer 0.1 action Function(pm_name_input_keyboard_action, ok_action, message) repeat False

    frame:
        has vbox:
            xalign .5
            yalign .5
            spacing 30
        label _(message):
            style "confirm_prompt"
            xalign 0.5
        text "[player]_" xalign 0.5
        hbox:
            xalign 0.5
            spacing 60
            textbutton _("Keyboard") action Function(pm_name_input_keyboard_action, ok_action, message)
            textbutton _("OK") action ok_action
