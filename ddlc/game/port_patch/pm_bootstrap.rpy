init -998 python:
    import os

    def pm_join_path(*parts):
        return os.path.normpath(os.path.join(*parts))

    def pm_safe_makedirs(path):
        if not path:
            return
        try:
            if not os.path.isdir(path):
                os.makedirs(path)
        except Exception as exc:
            pm_log("Could not create directory {0}: {1}".format(path, exc))

    def pm_get_default_base_dir():
        try:
            return config.basedir
        except Exception:
            return os.getcwd()

    pm_is_desktop_test = pm_env_flag("DESKTOP_TEST") or pm_env_flag("PORTMASTER_TEST")
    pm_is_portmaster = pm_env_flag("PORTMASTER") or pm_env_flag("PORTMASTER_MODE")
    pm_base_dir = os.environ.get("GAMEDIR", pm_get_default_base_dir())
    pm_conf_dir = os.environ.get("CONFDIR", pm_join_path(pm_base_dir, "conf"))
    pm_mods_dir = os.environ.get("PM_MODS_DIR", pm_join_path(pm_base_dir, "mods"))
    pm_original_dir = os.environ.get("PM_ORIGINAL_DIR", pm_join_path(pm_base_dir, "original"))
    pm_logs_dir = os.environ.get("PM_LOGS_DIR", pm_join_path(pm_base_dir, "logs"))

    for pm_dir in (pm_conf_dir, pm_mods_dir, pm_original_dir, pm_logs_dir):
        pm_safe_makedirs(pm_dir)

    if getattr(persistent, "pm_deleted_characters", None) is None:
        persistent.pm_deleted_characters = []

    if getattr(persistent, "pm_active_mod", None) is None:
        persistent.pm_active_mod = None

    pm_boot_count_value = getattr(persistent, "pm_boot_count", 0) or 0
    persistent.pm_boot_count = pm_boot_count_value + 1

    pm_log("{0} {1} bootstrap complete".format(PM_PORT_NAME, PM_PORT_VERSION))
    pm_log("desktop_test={0} portmaster={1}".format(pm_is_desktop_test, pm_is_portmaster))
    pm_log("base_dir={0}".format(pm_base_dir))
    pm_log("conf_dir={0}".format(pm_conf_dir))
    pm_log("mods_dir={0}".format(pm_mods_dir))
