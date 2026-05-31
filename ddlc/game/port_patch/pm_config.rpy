init -999 python:
    import os

    def pm_env_flag(name):
        value = os.environ.get(name, "")
        return value.lower() in ("1", "true", "yes", "on")

    def pm_env_int(name, default_value=None, minimum=None, maximum=None):
        try:
            value = int(str(os.environ.get(name, "")).strip())
        except Exception:
            return default_value

        if minimum is not None and value < minimum:
            value = minimum
        if maximum is not None and value > maximum:
            value = maximum

        return value

    def pm_env_text(name, default_value=""):
        return str(os.environ.get(name, default_value) or default_value).strip().lower()

    PM_PORT_NAME = "DDLC PortMaster Compatibility Wrapper"
    PM_PORT_VERSION = "0.5.0"
    PM_BASE_VIRTUAL_WIDTH = 1280
    PM_BASE_VIRTUAL_HEIGHT = 720
    PM_FOUR_THREE_FALLBACK_WIDTH = 960
    PM_FOUR_THREE_FALLBACK_HEIGHT = 720
    PM_R36_FALLBACK_WIDTH = 640
    PM_R36_FALLBACK_HEIGHT = 480
    PM_VALID_CHARACTERS = ("monika", "sayori", "natsuki", "yuri")
    PM_EXPECTED_ASSET_ROOT = "ddlc/original"
    PM_DEBUG = pm_env_flag("PM_DEBUG")
    PM_DEVICE_PROFILE = pm_env_text("PM_DEVICE_PROFILE", "unknown")
    PM_DEVICE_HINTS = pm_env_text("PM_DEVICE_HINTS", "")
    PM_MEMORY_CLASS = pm_env_text("PM_MEMORY_CLASS", "unknown")
    PM_SCREEN_CLASS = pm_env_text("PM_SCREEN_CLASS", "unknown")
    PM_SMALL_SCREEN = pm_env_flag("PM_SMALL_SCREEN")
    PM_PERFORMANCE_PROFILE = pm_env_text("PM_PERFORMANCE_PROFILE", "balanced")
    if PM_PERFORMANCE_PROFILE not in ("low", "balanced", "quality"):
        PM_PERFORMANCE_PROFILE = "balanced"
    PM_IMAGE_CACHE_SIZE = pm_env_int("PM_IMAGE_CACHE_SIZE", None, 8, 128)
    PM_PREDICT_STATEMENTS = pm_env_int("PM_PREDICT_STATEMENTS", None, 4, 100)
    PM_FRAMERATE = pm_env_int("PM_FRAMERATE", None, 15, 100)
    PM_GL_FRAMERATE = pm_env_int("PM_GL_FRAMERATE", None, 15, 100)
    PM_GL_POWERSAVE = not pm_env_flag("PM_DISABLE_GL_POWERSAVE")
    PM_NAME_ALLOWED_CHARS = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"

    PM_REQUIRED_ASSETS = (
        ("audio_archive", "original/game/audio.rpa", True, ""),
        ("images_archive", "original/game/images.rpa", True, ""),
        ("scripts_archive", "original/game/scripts.rpa", True, ""),
        ("fonts_archive", "original/game/fonts.rpa", True, ""),
        ("monika_character", "original/characters/monika.chr", True, ""),
        ("sayori_character", "original/characters/sayori.chr", True, ""),
        ("natsuki_character", "original/characters/natsuki.chr", True, ""),
        ("yuri_character", "original/characters/yuri.chr", True, ""),
    )

    PM_MISSING_ASSETS_MESSAGE = (
        "Required DDLC files are missing. Copy your original game archives to "
        "ddlc/original/game and character files to ddlc/original/characters."
    )

    def pm_log(message):
        try:
            renpy.log("[PM] " + str(message))
        except Exception:
            pass
