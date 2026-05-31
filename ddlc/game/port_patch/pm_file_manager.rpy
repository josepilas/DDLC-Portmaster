init -980 python:
    def pm_file_manager_delete(name):
        if pm_delete_character(name):
            return "{0}.chr deleted in virtual character layer.".format(name)
        return "Invalid character file."

    def pm_open_file_manager_context():
        try:
            renpy.call_in_new_context("pm_open_file_manager")
        except Exception as exc:
            pm_log("Could not open file manager: {0}".format(exc))

label pm_open_file_manager:
    $ pm_init_character_state()
    call screen pm_file_manager
    return

screen pm_file_manager():
    modal True
    tag pm_file_manager
    default selected_folder = "characters"
    default selected_file = None
    default status_message = "Select a character file."

    key "K_ESCAPE" action Return()
    key "K_F9" action Return()
    key "K_F10" action Return()

    frame:
        background "#f7f7f7"
        xfill True
        yfill True
        padding (0, 0)

        vbox:
            spacing 0
            xfill True
            yfill True

            frame:
                background "#174f9e"
                xfill True
                ysize 58
                padding (18, 10)
                text "File Manager" color "#ffffff" size 30

            hbox:
                spacing 10
                xfill True
                yfill True

                frame:
                    background "#edf2f8"
                    xsize 285
                    yfill True
                    padding (16, 16)
                    vbox:
                        spacing 12
                        text "Folders" color "#111111" size 24
                        textbutton "DIR  characters":
                            xfill True
                            yminimum 60
                            action [SetScreenVariable("selected_folder", "characters"), SetScreenVariable("selected_file", None), SetScreenVariable("status_message", "Opened characters folder.")]
                        null height 18
                        textbutton "Close":
                            xfill True
                            yminimum 60
                            action Return()

                frame:
                    background "#ffffff"
                    xfill True
                    yfill True
                    padding (20, 16)
                    vbox:
                        spacing 12
                        text "ddlc/original/characters" color "#111111" size 22

                        if selected_folder == "characters":
                            grid 2 2:
                                spacing 10
                                xfill True
                                for char_name in PM_VALID_CHARACTERS:
                                    $ char_exists = pm_character_exists(char_name)
                                    $ file_label = "FILE {0}.chr".format(char_name)
                                    if not char_exists:
                                        $ file_label = file_label + "\n(deleted)"
                                    textbutton file_label:
                                        xminimum 360
                                        yminimum 86
                                        sensitive char_exists
                                        action [SetScreenVariable("selected_file", char_name), SetScreenVariable("status_message", "{0}.chr selected.".format(char_name))]

                        null height 8
                        frame:
                            background "#e9e9e9"
                            xfill True
                            padding (14, 10)
                            vbox:
                                spacing 8
                                if selected_file:
                                    text "Selected: [selected_file].chr" color "#111111" size 20
                                else:
                                    text "Selected: none" color "#111111" size 20
                                text status_message color "#333333" size 18

                        hbox:
                            spacing 10
                            textbutton "Delete file":
                                yminimum 58
                                sensitive selected_file is not None and pm_character_exists(selected_file)
                                action [Function(pm_file_manager_delete, selected_file), SetScreenVariable("status_message", "Selected file deleted in virtual character layer."), SetScreenVariable("selected_file", None)]
                            textbutton "Restore all":
                                yminimum 58
                                action [Function(pm_restore_all_characters), SetScreenVariable("status_message", "All virtual character files restored."), SetScreenVariable("selected_file", None)]
                            textbutton "Close":
                                yminimum 58
                                action Return()
