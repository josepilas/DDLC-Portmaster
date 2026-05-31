init -990 python:
    def pm_normalize_character_name(name):
        if name is None:
            return None
        value = str(name).replace("\\", "/").split("/")[-1].strip().lower()
        if value.endswith(".chr"):
            value = value[:-4]
        if value in PM_VALID_CHARACTERS:
            return value
        return None

    def pm_save_persistent():
        try:
            renpy.save_persistent()
        except Exception as exc:
            pm_log("Could not save persistent data: {0}".format(exc))

    def pm_init_character_state():
        if getattr(persistent, "pm_deleted_characters", None) is None:
            persistent.pm_deleted_characters = []

        clean = []
        for item in list(persistent.pm_deleted_characters):
            normalized = pm_normalize_character_name(item)
            if normalized and normalized not in clean:
                clean.append(normalized)
        persistent.pm_deleted_characters = clean
        return True

    def pm_character_exists(name):
        pm_init_character_state()
        normalized = pm_normalize_character_name(name)
        if normalized is None:
            return False
        return normalized not in persistent.pm_deleted_characters

    def pm_delete_character(name):
        pm_init_character_state()
        normalized = pm_normalize_character_name(name)
        if normalized is None:
            pm_log("Rejected invalid character delete request: {0}".format(name))
            return False
        if normalized not in persistent.pm_deleted_characters:
            persistent.pm_deleted_characters.append(normalized)
            pm_save_persistent()
            pm_log("Virtual character deleted: {0}".format(normalized))
        return True

    def pm_restore_character(name):
        pm_init_character_state()
        normalized = pm_normalize_character_name(name)
        if normalized is None:
            return False
        if normalized in persistent.pm_deleted_characters:
            persistent.pm_deleted_characters.remove(normalized)
            pm_save_persistent()
            pm_log("Virtual character restored: {0}".format(normalized))
        return True

    def pm_restore_all_characters():
        persistent.pm_deleted_characters = []
        pm_save_persistent()
        pm_log("All virtual characters restored")
        return True

    def pm_get_character_status(name):
        normalized = pm_normalize_character_name(name)
        if normalized is None:
            return {
                "name": None,
                "valid": False,
                "exists": False,
                "deleted": False,
            }
        exists = pm_character_exists(normalized)
        return {
            "name": normalized,
            "valid": True,
            "exists": exists,
            "deleted": not exists,
        }

    def pm_list_characters():
        pm_init_character_state()
        result = []
        for name in PM_VALID_CHARACTERS:
            result.append(pm_get_character_status(name))
        return result
