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
        root = os.environ.get("PM_ORIGINAL_BASE_ROOT", "")
        if root:
            return os.path.basename(root.rstrip("\\/")) or "original"
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

    pm_log("original container={0}".format(os.environ.get("PM_ORIGINAL_CONTAINER_ROOT", pm_original_dir)))
