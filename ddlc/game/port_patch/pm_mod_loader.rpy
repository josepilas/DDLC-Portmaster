init -960 python:
    import os

    def pm_normalize_mod_name(name):
        if name is None:
            return None
        value = str(name).strip().replace("\\", "/").split("/")[-1]
        if value in ("", ".", ".."):
            return None
        allowed = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-"
        for ch in value:
            if ch not in allowed:
                return None
        return value

    def pm_get_active_mod():
        if getattr(persistent, "pm_active_mod", None) is None:
            persistent.pm_active_mod = None
        active = pm_normalize_mod_name(persistent.pm_active_mod)
        if active:
            return active

        active_dir = os.path.join(pm_mods_dir, "active")
        try:
            if os.path.isdir(active_dir) and os.listdir(active_dir):
                return "active"
        except Exception as exc:
            pm_log("Could not inspect active mod folder: {0}".format(exc))
        return None

    def pm_set_active_mod(name):
        normalized = pm_normalize_mod_name(name)
        if normalized is None:
            return False
        persistent.pm_active_mod = normalized
        pm_save_persistent()
        pm_log("Active mod set to {0}".format(normalized))
        return True

    def pm_clear_active_mod():
        persistent.pm_active_mod = None
        pm_save_persistent()
        pm_log("Active mod cleared")
        return True

    def pm_is_mod_active():
        return pm_get_active_mod() is not None

    # Future architecture:
    # - mods/ptbr can hold translation files.
    # - mods/active can hold the currently selected simple mod.
    # - Dynamic .rpa mounting is intentionally not implemented in this scaffold.
