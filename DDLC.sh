#!/bin/bash

XDG_DATA_HOME="${XDG_DATA_HOME:-${HOME:-/tmp}/.local/share}"

if [ -d "/opt/system/Tools/PortMaster/" ]; then
  controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/" ]; then
  controlfolder="/opt/tools/PortMaster"
elif [ -d "${XDG_DATA_HOME}/PortMaster/" ]; then
  controlfolder="${XDG_DATA_HOME}/PortMaster"
else
  controlfolder="/roms/ports/PortMaster"
fi

if [ -f "${controlfolder}/control.txt" ]; then
  # shellcheck source=/dev/null
  source "${controlfolder}/control.txt"
else
  echo "PortMaster control.txt was not found at ${controlfolder}/control.txt"
fi

if [ -f "${controlfolder}/device_info.txt" ]; then
  # shellcheck source=/dev/null
  source "${controlfolder}/device_info.txt"
else
  echo "PortMaster device_info.txt was not found at ${controlfolder}/device_info.txt"
fi

if [ -n "${CFW_NAME:-}" ] && [ -f "${controlfolder}/mod_${CFW_NAME}.txt" ]; then
  # shellcheck source=/dev/null
  source "${controlfolder}/mod_${CFW_NAME}.txt"
fi

if type get_controls >/dev/null 2>&1; then
  get_controls
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PORTDIR="${PORTDIR:-${SCRIPT_DIR}}"
GAMEDIR="${GAMEDIR:-${PORTDIR}/ddlc}"
CONFDIR="${CONFDIR:-${GAMEDIR}/conf}"
PM_SAVEDIR="${PM_SAVEDIR:-${GAMEDIR}/saves}"
LOGDIR="${GAMEDIR}/logs"
RUNTIME_ROOT="${GAMEDIR}/runtime/renpy-7.5.3-arm"
ORIGINAL_CONTAINER="${PM_ORIGINAL_CONTAINER:-${GAMEDIR}/original}"
USER_CONFIG_FILE="${GAMEDIR}/user_configs.txt"
PM_CONTAINER_MANIFEST="${GAMEDIR}/persistent/container_overlay_files.txt"
WESTON_RUNTIME="${PM_WESTON_RUNTIME:-weston_pkg_0.2}"
WESTON_DIR="${PM_WESTON_DIR:-/tmp/weston}"
PM_USE_WESTON="${PM_USE_WESTON:-1}"

mkdir -p "${CONFDIR}" "${LOGDIR}" "${PM_SAVEDIR}" "${GAMEDIR}/persistent" "${ORIGINAL_CONTAINER}"

LOGFILE="${LOGDIR}/ddlc-portmaster.log"
CRASHLOG="${LOGDIR}/log.txt"
: > "${LOGFILE}"
if [ -e /dev/fd/1 ] || [ -d /dev/fd ]; then
  exec > >(tee -a "${LOGFILE}") 2>&1
else
  exec >> "${LOGFILE}" 2>&1
  echo "No /dev/fd available; logging to ${LOGFILE} only."
fi

pm_tty_chmod() {
  [ -e /dev/tty0 ] || return 0
  if [ -n "${ESUDO:-}" ]; then
    ${ESUDO} chmod 666 /dev/tty0 >/dev/null 2>&1 || true
  else
    chmod 666 /dev/tty0 >/dev/null 2>&1 || true
  fi
}

pm_sudo() {
  if [ -n "${ESUDO:-}" ]; then
    ${ESUDO} "$@"
  else
    "$@"
  fi
}

pm_tty_clear() {
  [ -e /dev/tty0 ] || return 0
  pm_tty_chmod
  printf '\033c' > /dev/tty0 2>/dev/null || true
}

pm_tty_message() {
  [ -e /dev/tty0 ] || return 0
  pm_tty_chmod
  printf '\033c' > /dev/tty0 2>/dev/null || true
  printf '%s\n' "$1" > /dev/tty0 2>/dev/null || true
}

pm_tty_splash_unused() {
  [ -e /dev/tty0 ] || return 0
  pm_tty_chmod
  printf '\033c' > /dev/tty0 2>/dev/null || true
  cat > /dev/tty0 2>/dev/null <<'PM_SPLASH' || true
Loading... Please Wait.

██████╗ ██╗██╗      █████╗ ███████╗
██╔══██╗██║██║     ██╔══██╗██╔════╝
██████╔╝██║██║     ███████║███████╗
██╔═══╝ ██║██║     ██╔══██║╚════██║
██║     ██║███████╗██║  ██║███████║
╚═╝     ╚═╝╚══════╝╚═╝  ╚═╝╚══════╝

                  __
                 /  \
                / /\ \
               / /  \ \
              / /    \ \
             / /      \ \
 ___________/_/________\ \___________
|  _____________________\ \________  |
 \ \      / /            \ \      / /
  \ \    / /              \ \    / /
   \ \  / /                \ \  / /
    \ \/ /                  \ \/ /
     \/ /                    \/ /
     / /\                    / /\
    / /\ \                  / /\ \
   / /  \ \                / /  \ \
  / /    \ \              / /    \ \
 / /______\ \____________/_/______\ \
|__________\ \_______________________|
            \ \        / /
             \ \      / /
              \ \    / /
               \ \  / /
                \ \/ /
                 \__/
PM_SPLASH
}

pm_tty_splash_compact() {
  [ -e /dev/tty0 ] || return 0
  pm_tty_chmod
  printf '\033c' > /dev/tty0 2>/dev/null || true
  cat > /dev/tty0 2>/dev/null <<'PM_SPLASH_COMPACT' || true
Loading... Please Wait.

 ____ ___ _     _    ____
|  _ \_ _| |   / \  / ___|
| |_) | || |  / _ \ \___ \
|  __/| || |_| ___ \ ___) |
|_|  |___|____/_/ \_\____/

       /\
      //\\
 ____//__\\____
 \.-//----\\-,/
  \v/      \v/
  /\\      //\
 //_\\____//_\\
'----\\--//----`
      \\//
       \/
PM_SPLASH_COMPACT
}

pm_tty_splash_compact

echo "=== DDLC PortMaster ==="
echo "Port dir: ${PORTDIR}"
echo "Game dir: ${GAMEDIR}"
echo "Control folder: ${controlfolder}"
echo "Runtime root: ${RUNTIME_ROOT}"
echo "Date: $(date)"

pm_is_uint() {
  case "${1:-}" in
    ""|*[!0-9]*)
      return 1
      ;;
    *)
      return 0
      ;;
  esac
}

pm_lower() {
  printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]'
}

pm_trim() {
  printf '%s' "${1:-}" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//'
}

ensure_user_config_file() {
  if [ -f "${USER_CONFIG_FILE}" ]; then
    return 0
  fi

  cat > "${USER_CONFIG_FILE}" <<'PM_USER_CONFIG'
# DDLC PortMaster - user_configs.txt
#
# Edit this file on your computer before playing.
# Change only the value after "=". Lines starting with "#" are ignored.
#
# DEVICE PROFILE
# device_profile:
#   0 = auto detect
#   1 = R36S / 640x480 vertical 4:3
#   2 = R36H / 640x480 horizontal 4:3
#   3 = R36H wide / 16:9
#   4 = generic RK3326
device_profile=0
#
# RESOLUTION
# resolution_mode:
#   0 = auto detect, recommended
#   1 = 640x480 4:3, recommended for R36S/R36H 4:3
#   2 = 1280x720 16:9, wide devices
#   3 = 960x720 4:3, sharper but heavier than 640x480
#   4 = custom, uses custom_width and custom_height below
resolution_mode=0
custom_width=640
custom_height=480
#
# custom_aspect is only used by resolution_mode=4:
#   0 = auto
#   1 = 4:3
#   2 = 16:9
custom_aspect=0
#
# aspect_scale:
#   1 = fit, no cropping, recommended
#   2 = stretch, fills 4:3 screens but distorts the image
aspect_scale=1
#
# fullscreen:
#   0 = windowed
#   1 = fullscreen, recommended
fullscreen=1
#
# PERFORMANCE
# performance_mode:
#   0 = auto
#   1 = low, recommended for R36S/R36H/RK3326
#   2 = balanced
#   3 = quality
performance_mode=0
#
# menu_optimization:
#   0 = auto, recommended
#   1 = force static menu background + no particles
#   2 = force original animated DDLC menu
menu_optimization=0
#
# fps_limit:
#   0 = auto, recommended
#   30 = recommended for RK3326 handhelds
#   60 = smoother but heavier
fps_limit=0
#
# quick_menu:
#   0 = hidden, recommended for handheld buttons
#   1 = visible touch quick menu
quick_menu=0
#
# virtual_keyboard:
#   0 = use normal Ren'Py text input
#   1 = use controller-friendly virtual keyboard, recommended
virtual_keyboard=1
#
# clear_cache:
#   0 = auto, recommended
#   1 = clear Ren'Py cache every launch
#   2 = never clear cache
clear_cache=0
PM_USER_CONFIG
}

load_user_configs() {
  local line key value
  local cfg_device="0"
  local cfg_resolution="0"
  local cfg_custom_width=""
  local cfg_custom_height=""
  local cfg_custom_aspect="0"
  local cfg_aspect_scale="1"
  local cfg_fullscreen="1"
  local cfg_performance="0"
  local cfg_menu="0"
  local cfg_fps="0"
  local cfg_quick="0"
  local cfg_keyboard="1"
  local cfg_cache="0"

  ensure_user_config_file || return 0

  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%%#*}"
    line="$(pm_trim "${line}")"
    [ -n "${line}" ] || continue

    case "${line}" in
      *=*)
        key="$(pm_lower "$(pm_trim "${line%%=*}")")"
        value="$(pm_trim "${line#*=}")"
        value="${value%\"}"
        value="${value#\"}"
        ;;
      *)
        continue
        ;;
    esac

    case "${key}" in
      device_profile) cfg_device="${value}" ;;
      resolution_mode|resolution) cfg_resolution="${value}" ;;
      custom_width) cfg_custom_width="${value}" ;;
      custom_height) cfg_custom_height="${value}" ;;
      custom_aspect) cfg_custom_aspect="${value}" ;;
      aspect_scale) cfg_aspect_scale="${value}" ;;
      fullscreen) cfg_fullscreen="${value}" ;;
      performance_mode|performance) cfg_performance="${value}" ;;
      menu_optimization|menu_optimize) cfg_menu="${value}" ;;
      fps_limit|fps) cfg_fps="${value}" ;;
      quick_menu) cfg_quick="${value}" ;;
      virtual_keyboard) cfg_keyboard="${value}" ;;
      clear_cache) cfg_cache="${value}" ;;
    esac
  done < "${USER_CONFIG_FILE}"

  case "$(pm_lower "${cfg_device}")" in
    1|r36s) PM_DEVICE_PROFILE="r36s" ;;
    2|r36h|r36h_4x3|r36h-4x3) PM_DEVICE_PROFILE="r36h" ;;
    3|r36h_wide|r36h-wide|wide) PM_DEVICE_PROFILE="r36h_wide" ;;
    4|rk3326) PM_DEVICE_PROFILE="rk3326" ;;
  esac

  case "$(pm_lower "${cfg_resolution}")" in
    1|640x480|r36|r36s|r36h)
      PM_SCREEN_WIDTH="640"
      PM_SCREEN_HEIGHT="480"
      PM_ASPECT_MODE="4:3"
      ;;
    2|1280x720|720p|16:9|16x9|wide)
      PM_SCREEN_WIDTH="1280"
      PM_SCREEN_HEIGHT="720"
      PM_ASPECT_MODE="16:9"
      ;;
    3|960x720)
      PM_SCREEN_WIDTH="960"
      PM_SCREEN_HEIGHT="720"
      PM_ASPECT_MODE="4:3"
      ;;
    4|custom)
      if pm_is_uint "${cfg_custom_width}" && pm_is_uint "${cfg_custom_height}"; then
        PM_SCREEN_WIDTH="${cfg_custom_width}"
        PM_SCREEN_HEIGHT="${cfg_custom_height}"
      fi
      case "$(pm_lower "${cfg_custom_aspect}")" in
        1|4:3|4x3) PM_ASPECT_MODE="4:3" ;;
        2|16:9|16x9) PM_ASPECT_MODE="16:9" ;;
        *) PM_ASPECT_MODE="${PM_ASPECT_MODE:-auto}" ;;
      esac
      ;;
  esac

  case "$(pm_lower "${cfg_aspect_scale}")" in
    2|stretch) PM_ASPECT_SCALE="stretch" ;;
    1|fit|*) PM_ASPECT_SCALE="fit" ;;
  esac

  case "$(pm_lower "${cfg_fullscreen}")" in
    0|off|false|no) PM_FULLSCREEN="0" ;;
    1|on|true|yes) PM_FULLSCREEN="1" ;;
  esac

  case "$(pm_lower "${cfg_performance}")" in
    1|low) PM_PERFORMANCE_PROFILE="low" ;;
    2|balanced) PM_PERFORMANCE_PROFILE="balanced" ;;
    3|quality) PM_PERFORMANCE_PROFILE="quality" ;;
  esac

  case "$(pm_lower "${cfg_menu}")" in
    1|on|true|yes) PM_MENU_OPTIMIZE="1" ;;
    2|off|false|no|original) PM_MENU_OPTIMIZE="0" ;;
  esac

  if pm_is_uint "${cfg_fps}" && [ "${cfg_fps}" -gt 0 ]; then
    PM_FRAMERATE="${cfg_fps}"
    PM_GL_FRAMERATE="${cfg_fps}"
  fi

  case "$(pm_lower "${cfg_quick}")" in
    0|off|false|no) PM_SHOW_TOUCH_QUICK_MENU="0" ;;
    1|on|true|yes) PM_SHOW_TOUCH_QUICK_MENU="1" ;;
  esac

  case "$(pm_lower "${cfg_keyboard}")" in
    0|off|false|no) PM_USE_VIRTUAL_KEYBOARD="0" ;;
    1|on|true|yes) PM_USE_VIRTUAL_KEYBOARD="1" ;;
  esac

  case "$(pm_lower "${cfg_cache}")" in
    1|always) PM_CLEAR_RENPY_CACHE="1" ;;
    2|never) PM_CLEAR_RENPY_CACHE="0" ;;
    *) PM_CLEAR_RENPY_CACHE="${PM_CLEAR_RENPY_CACHE:-auto}" ;;
  esac

  export PM_DEVICE_PROFILE PM_SCREEN_WIDTH PM_SCREEN_HEIGHT PM_ASPECT_MODE PM_ASPECT_SCALE PM_FULLSCREEN
  export PM_PERFORMANCE_PROFILE PM_MENU_OPTIMIZE PM_FRAMERATE PM_GL_FRAMERATE PM_SHOW_TOUCH_QUICK_MENU
  export PM_USE_VIRTUAL_KEYBOARD PM_CLEAR_RENPY_CACHE

  echo "Loaded user config: ${USER_CONFIG_FILE}"
}

read_device_hints() {
  local hints="${PM_DEVICE_HINTS:-}"
  local path
  local value

  for path in \
    /proc/device-tree/model \
    /sys/firmware/devicetree/base/model \
    /etc/hostname; do
    if [ -r "${path}" ]; then
      value="$(tr -d '\000\r\n' < "${path}" 2>/dev/null || true)"
      hints="${hints} ${value}"
    fi
  done

  if [ -r /proc/cpuinfo ]; then
    value="$(grep -E 'Hardware|Model|Processor|Revision' /proc/cpuinfo 2>/dev/null | tr '\n' ' ' || true)"
    hints="${hints} ${value}"
  fi

  for value in "${DEVICE_NAME:-}" "${DEVICE:-}" "${PORTMASTER_DEVICE:-}" "${PM_DEVICE:-}" "${CFW_NAME:-}"; do
    hints="${hints} ${value}"
  done

  PM_DEVICE_HINTS="$(pm_lower "${hints}")"
  export PM_DEVICE_HINTS
}

normalize_device_profile() {
  case "$(pm_lower "${1:-}")" in
    r36s|r35s|rk3326-r36s|gameconsole-r36s)
      printf '%s\n' "r36s"
      ;;
    r36h-wide|r36h_wide|r36h16x9|r36h-16x9|r36h_16x9)
      printf '%s\n' "r36h_wide"
      ;;
    r36h|rk3326-r36h|gameconsole-r36h)
      printf '%s\n' "r36h"
      ;;
    rk3326|rockchip-rk3326|rk3326-generic)
      printf '%s\n' "rk3326"
      ;;
    *)
      printf '%s\n' "unknown"
      ;;
  esac
}

detect_memory_class() {
  local mem_kb=""

  if [ -n "${PM_MEMORY_CLASS:-}" ]; then
    PM_MEMORY_TOTAL_KB="${PM_MEMORY_TOTAL_KB:-}"
    export PM_MEMORY_TOTAL_KB PM_MEMORY_CLASS
    return 0
  fi

  if [ -r /proc/meminfo ]; then
    mem_kb="$(awk '/MemTotal:/ { print $2; exit }' /proc/meminfo 2>/dev/null || true)"
  fi

  if pm_is_uint "${mem_kb}"; then
    PM_MEMORY_TOTAL_KB="${mem_kb}"
    if [ "${mem_kb}" -le 350000 ]; then
      PM_MEMORY_CLASS="256mb"
    elif [ "${mem_kb}" -le 700000 ]; then
      PM_MEMORY_CLASS="512mb"
    elif [ "${mem_kb}" -le 1250000 ]; then
      PM_MEMORY_CLASS="1gb"
    else
      PM_MEMORY_CLASS="high"
    fi
  else
    PM_MEMORY_TOTAL_KB=""
    PM_MEMORY_CLASS="${PM_MEMORY_CLASS:-unknown}"
  fi

  export PM_MEMORY_TOTAL_KB PM_MEMORY_CLASS
}

detect_device_profile() {
  local profile

  read_device_hints
  profile="$(normalize_device_profile "${PM_DEVICE_PROFILE:-}")"

  if [ "${profile}" = "unknown" ]; then
    case "${PM_DEVICE_HINTS}" in
      *r36h*)
        profile="r36h"
        ;;
      *r36s*|*r35s*)
        profile="r36s"
        ;;
      *rk3326*|*rockchip*)
        profile="rk3326"
        ;;
    esac
  fi

  PM_DEVICE_PROFILE="${profile}"
  export PM_DEVICE_PROFILE
}

apply_device_defaults() {
  PM_DEVICE_FALLBACK_WIDTH="${PM_DEVICE_FALLBACK_WIDTH:-}"
  PM_DEVICE_FALLBACK_HEIGHT="${PM_DEVICE_FALLBACK_HEIGHT:-}"

  case "${PM_DEVICE_PROFILE}" in
    r36s)
      PM_DEVICE_FALLBACK_WIDTH="${PM_DEVICE_FALLBACK_WIDTH:-640}"
      PM_DEVICE_FALLBACK_HEIGHT="${PM_DEVICE_FALLBACK_HEIGHT:-480}"
      PM_ASPECT_MODE="${PM_ASPECT_MODE:-4:3}"
      PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}"
      ;;
    r36h_wide)
      PM_DEVICE_FALLBACK_WIDTH="${PM_DEVICE_FALLBACK_WIDTH:-1280}"
      PM_DEVICE_FALLBACK_HEIGHT="${PM_DEVICE_FALLBACK_HEIGHT:-720}"
      PM_ASPECT_MODE="${PM_ASPECT_MODE:-16:9}"
      PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}"
      ;;
    r36h)
      PM_DEVICE_FALLBACK_WIDTH="${PM_DEVICE_FALLBACK_WIDTH:-640}"
      PM_DEVICE_FALLBACK_HEIGHT="${PM_DEVICE_FALLBACK_HEIGHT:-480}"
      PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}"
      ;;
    rk3326)
      PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}"
      ;;
  esac

  if [ "${PM_DEVICE_PROFILE}" = "r36s" ] || [ "${PM_DEVICE_PROFILE}" = "r36h" ] || [ "${PM_DEVICE_PROFILE}" = "r36h_wide" ] || [ "${PM_DEVICE_PROFILE}" = "rk3326" ]; then
    PM_HANDHELD_MODE="${PM_HANDHELD_MODE:-1}"
    PM_ENABLE_RENPY_PAD="${PM_ENABLE_RENPY_PAD:-1}"
    PM_USE_VIRTUAL_KEYBOARD="${PM_USE_VIRTUAL_KEYBOARD:-1}"
    PM_SHOW_TOUCH_QUICK_MENU="${PM_SHOW_TOUCH_QUICK_MENU:-0}"
    PM_SMALL_SCREEN="${PM_SMALL_SCREEN:-1}"
    PM_MENU_OPTIMIZE="${PM_MENU_OPTIMIZE:-1}"
    PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-30}"
    PM_FRAMERATE="${PM_FRAMERATE:-30}"
    RENPY_RENDERER="${RENPY_RENDERER:-gl2}"
    RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}"

    if [ -z "${PM_PERFORMANCE_PROFILE:-}" ]; then
      if [ "${PM_MEMORY_CLASS}" = "256mb" ] || [ "${PM_MEMORY_CLASS}" = "512mb" ]; then
        PM_PERFORMANCE_PROFILE="low"
      elif [ "${PM_DEVICE_PROFILE}" = "r36s" ] || [ "${PM_DEVICE_PROFILE}" = "r36h" ] || [ "${PM_DEVICE_PROFILE}" = "rk3326" ]; then
        PM_PERFORMANCE_PROFILE="low"
      else
        PM_PERFORMANCE_PROFILE="balanced"
      fi
    fi

    if [ "${PM_PERFORMANCE_PROFILE}" = "low" ]; then
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-24}"
      PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-96}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-12}"
    elif [ "${PM_MEMORY_CLASS}" = "256mb" ]; then
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-16}"
      PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-64}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-8}"
    elif [ "${PM_MEMORY_CLASS}" = "512mb" ]; then
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-24}"
      PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-96}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-12}"
    else
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-48}"
      PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-160}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-28}"
    fi
  fi

  export PM_DEVICE_FALLBACK_WIDTH PM_DEVICE_FALLBACK_HEIGHT
  export PM_HANDHELD_MODE PM_ENABLE_RENPY_PAD PM_USE_VIRTUAL_KEYBOARD PM_SHOW_TOUCH_QUICK_MENU PM_SMALL_SCREEN
  export PM_PERFORMANCE_PROFILE PM_IMAGE_CACHE_SIZE PM_IMAGE_CACHE_SIZE_MB PM_PREDICT_STATEMENTS PM_MENU_OPTIMIZE
  export PM_GL_FRAMERATE PM_FRAMERATE RENPY_RENDERER RENPY_GL_VSYNC
}

detect_display_mode() {
  local fb_size=""
  local detected_width=""
  local detected_height=""
  local geometry=""
  local ratio1000=""

  if [ -z "${PM_SCREEN_WIDTH:-}" ] || [ -z "${PM_SCREEN_HEIGHT:-}" ]; then
    if [ -r /sys/class/graphics/fb0/virtual_size ]; then
      fb_size="$(tr -d '\r\n ' < /sys/class/graphics/fb0/virtual_size)"
      detected_width="${fb_size%,*}"
      detected_height="${fb_size#*,}"
    fi

    if { [ -z "${detected_width}" ] || [ -z "${detected_height}" ]; } && command -v fbset >/dev/null 2>&1; then
      geometry="$(fbset -s 2>/dev/null | awk '/geometry/ { print $2 " " $3; exit }')"
      if [ -n "${geometry}" ]; then
        # shellcheck disable=SC2086
        set -- ${geometry}
        detected_width="${1:-}"
        detected_height="${2:-}"
      fi
    fi

    if pm_is_uint "${detected_width}" && pm_is_uint "${detected_height}"; then
      PM_SCREEN_WIDTH="${detected_width}"
      PM_SCREEN_HEIGHT="${detected_height}"
    else
      PM_SCREEN_WIDTH="${PM_SCREEN_WIDTH:-1280}"
      PM_SCREEN_HEIGHT="${PM_SCREEN_HEIGHT:-720}"
      PM_SCREEN_WIDTH="${PM_DEVICE_FALLBACK_WIDTH:-${PM_SCREEN_WIDTH}}"
      PM_SCREEN_HEIGHT="${PM_DEVICE_FALLBACK_HEIGHT:-${PM_SCREEN_HEIGHT}}"
    fi
  fi

  PM_ASPECT_MODE="${PM_ASPECT_MODE:-auto}"
  case "${PM_ASPECT_MODE}" in
    4x3|4X3)
      PM_ASPECT_MODE="4:3"
      ;;
    16x9|16X9)
      PM_ASPECT_MODE="16:9"
      ;;
  esac

  if [ "${PM_ASPECT_MODE}" = "auto" ] && pm_is_uint "${PM_SCREEN_WIDTH}" && pm_is_uint "${PM_SCREEN_HEIGHT}" && [ "${PM_SCREEN_HEIGHT}" -gt 0 ]; then
    ratio1000=$((PM_SCREEN_WIDTH * 1000 / PM_SCREEN_HEIGHT))
    if [ "${ratio1000}" -le 1450 ]; then
      PM_ASPECT_MODE="4:3"
    else
      PM_ASPECT_MODE="16:9"
    fi
  fi

  PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}"
  PM_FULLSCREEN="${PM_FULLSCREEN:-1}"

  if pm_is_uint "${PM_SCREEN_WIDTH}" && pm_is_uint "${PM_SCREEN_HEIGHT}"; then
    if [ "${PM_SCREEN_WIDTH}" -le 640 ] && [ "${PM_SCREEN_HEIGHT}" -le 480 ]; then
      PM_SCREEN_CLASS="small"
    else
      PM_SCREEN_CLASS="standard"
    fi
  else
    PM_SCREEN_CLASS="${PM_SCREEN_CLASS:-unknown}"
  fi

  if [ "${PM_DEVICE_PROFILE}" = "r36h" ] && [ "${PM_ASPECT_MODE}" = "16:9" ]; then
    PM_DEVICE_PROFILE="r36h_wide"
  fi

  export PM_SCREEN_WIDTH PM_SCREEN_HEIGHT PM_ASPECT_MODE PM_ASPECT_SCALE PM_FULLSCREEN PM_SCREEN_CLASS PM_DEVICE_PROFILE
  echo "Device profile: ${PM_DEVICE_PROFILE}, memory ${PM_MEMORY_CLASS:-unknown} (${PM_MEMORY_TOTAL_KB:-?} KB), screen class ${PM_SCREEN_CLASS}"
  echo "Display: ${PM_SCREEN_WIDTH}x${PM_SCREEN_HEIGHT}, mode ${PM_ASPECT_MODE}, scale ${PM_ASPECT_SCALE}, fullscreen ${PM_FULLSCREEN}"
}

detect_runtime() {
  local arch
  arch="$(uname -m)"

  case "${arch}" in
    aarch64|arm64)
      PM_RUNTIME_ARCH="aarch64"
      RENPY_PLATFORM="linux-aarch64"
      RUNTIME="${GAMEDIR}/renpy.aarch64"
      RUNTIME_BIN="${RUNTIME_ROOT}/lib/py2-linux-aarch64/renpy"
      GL4ES_ARCH="aarch64"
      ;;
    armv7l|armv7*|armhf|arm*)
      PM_RUNTIME_ARCH="armhf"
      RENPY_PLATFORM="linux-armv7l"
      RUNTIME="${GAMEDIR}/renpy.armhf"
      RUNTIME_BIN="${RUNTIME_ROOT}/lib/py2-linux-armv7l/renpy"
      GL4ES_ARCH="armhf"
      ;;
    *)
      if [ "${PM_PREP_ONLY:-0}" = "1" ]; then
        PM_RUNTIME_ARCH="prep-only"
        RENPY_PLATFORM="linux-aarch64"
        RUNTIME="/bin/true"
        RUNTIME_BIN="/bin/true"
        GL4ES_ARCH="aarch64"
        export PM_RUNTIME_ARCH RENPY_PLATFORM
        echo "Unsupported architecture ${arch}, but PM_PREP_ONLY=1 so runtime launch is skipped."
        return 0
      fi
      echo "Unsupported architecture for this PortMaster build: ${arch}"
      echo "Expected aarch64 or armhf."
      return 1
      ;;
  esac

  export PM_RUNTIME_ARCH RENPY_PLATFORM
  echo "Runtime architecture: ${PM_RUNTIME_ARCH}"
  echo "Runtime launcher: ${RUNTIME}"
  echo "Runtime binary: ${RUNTIME_BIN}"
  return 0
}

pm_container_has_required_assets() {
  local root="$1"

  [ -f "${root}/game/audio.rpa" ] || return 1
  [ -f "${root}/game/images.rpa" ] || return 1
  [ -f "${root}/game/scripts.rpa" ] || return 1
  [ -f "${root}/game/fonts.rpa" ] || return 1
  [ -f "${root}/characters/monika.chr" ] || return 1
  [ -f "${root}/characters/sayori.chr" ] || return 1
  [ -f "${root}/characters/natsuki.chr" ] || return 1
  [ -f "${root}/characters/yuri.chr" ] || return 1
  return 0
}

detect_original_container() {
  local entry

  PM_ORIGINAL_CONTAINER_ROOT="${ORIGINAL_CONTAINER}"
  PM_ORIGINAL_BASE_ROOT=""

  if pm_container_has_required_assets "${ORIGINAL_CONTAINER}"; then
    PM_ORIGINAL_BASE_ROOT="${ORIGINAL_CONTAINER}"
  else
    for entry in "${ORIGINAL_CONTAINER}"/*; do
      [ -d "${entry}" ] || continue
      if pm_container_has_required_assets "${entry}"; then
        PM_ORIGINAL_BASE_ROOT="${entry}"
        break
      fi
    done
  fi

  if [ -z "${PM_ORIGINAL_BASE_ROOT}" ]; then
    echo "Could not find a valid DDLC root inside ${ORIGINAL_CONTAINER}."
    echo "Expected game/*.rpa and characters/*.chr either directly in original/ or one folder below it."
    return 1
  fi

  PM_ORIGINAL_DIR="${PM_ORIGINAL_BASE_ROOT}"
  export PM_ORIGINAL_CONTAINER_ROOT PM_ORIGINAL_BASE_ROOT PM_ORIGINAL_DIR
  echo "Original container root: ${PM_ORIGINAL_CONTAINER_ROOT}"
  echo "Original asset root: ${PM_ORIGINAL_BASE_ROOT}"
  return 0
}

clean_previous_container_overlay() {
  local relpath
  local fullpath

  for manifest in "${PM_CONTAINER_MANIFEST}" "${GAMEDIR}/persistent/mod_overlay_files.txt"; do
    [ -f "${manifest}" ] || continue
    echo "Cleaning previous runtime overlay: ${manifest}"
    while IFS= read -r relpath || [ -n "${relpath}" ]; do
      case "${relpath}" in
        ""|/*|*"/../"*|*"../"*|*"..")
          echo "Skipping unsafe tracked path: ${relpath}"
          continue
          ;;
      esac

      fullpath="${GAMEDIR}/${relpath}"
      if [ -f "${fullpath}" ] || [ -L "${fullpath}" ]; then
        rm -f "${fullpath}" 2>/dev/null || true
      fi
    done < "${manifest}"
    rm -f "${manifest}" 2>/dev/null || true
  done
}

pm_track_container_file() {
  printf '%s\n' "$1" >> "${PM_CONTAINER_MANIFEST}"
}

pm_is_protected_container_path() {
  case "$1" in
    game/port_patch/*|game/python-packages/singleton.py)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pm_mount_file() {
  local src="$1"
  local dst="$2"
  local rel="$3"
  local parent

  if pm_is_protected_container_path "${rel}"; then
    echo "Keeping wrapper-owned file: ${rel}"
    return 0
  fi

  parent="$(dirname "${dst}")"
  mkdir -p "${parent}" || return 1
  rm -f "${dst}" 2>/dev/null || true

  if ln -s "${src}" "${dst}" 2>/dev/null; then
    :
  else
    cp "${src}" "${dst}" || return 1
  fi

  pm_track_container_file "${rel}"
  return 0
}

pm_mount_tree() {
  local src_root="$1"
  local dst_root="$2"
  local rel_root="$3"
  local list_file="${GAMEDIR}/persistent/container_find.$$"
  local rel
  local clean_rel_root="${rel_root%/}"

  [ -d "${src_root}" ] || return 0

  : > "${list_file}" || return 1
  (cd "${src_root}" && find . \( -type f -o -type l \) -print > "${list_file}") || {
    rm -f "${list_file}" 2>/dev/null || true
    return 1
  }

  while IFS= read -r rel || [ -n "${rel}" ]; do
    rel="${rel#./}"
    [ -n "${rel}" ] || continue
    pm_mount_file "${src_root}/${rel}" "${dst_root}/${rel}" "${clean_rel_root}/${rel}" || {
      rm -f "${list_file}" 2>/dev/null || true
      return 1
    }
  done < "${list_file}"

  rm -f "${list_file}" 2>/dev/null || true
  return 0
}

pm_should_skip_root_entry() {
  case "$1" in
    game|characters|lib|renpy|cache|saves|logs|persistent|DDLC.exe|DDLC.py|DDLC.sh|README|README.*|COPYING|COPYING.*|COPYRIGHT|COPYRIGHT.*|LICENSE|LICENSE.*|log.txt)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

pm_mount_root_sidecars() {
  local root="$1"
  local entry
  local base

  for entry in "${root}"/* "${root}"/.[!.]* "${root}"/..?*; do
    [ -e "${entry}" ] || continue
    base="$(basename "${entry}")"
    if [ -n "${PM_ORIGINAL_BASE_ROOT:-}" ] && [ "${entry}" = "${PM_ORIGINAL_BASE_ROOT}" ]; then
      continue
    fi
    if pm_container_has_required_assets "${entry}"; then
      continue
    fi
    if pm_should_skip_root_entry "${base}"; then
      continue
    fi

    if [ -d "${entry}" ]; then
      pm_mount_tree "${entry}" "${GAMEDIR}/${base}" "${base}" || return 1
    elif [ -f "${entry}" ] || [ -L "${entry}" ]; then
      pm_mount_file "${entry}" "${GAMEDIR}/${base}" "${base}" || return 1
    fi
  done

  return 0
}

pm_mount_container_root() {
  local root="$1"

  [ -d "${root}" ] || return 0
  pm_mount_tree "${root}/game" "${GAMEDIR}/game" "game" || return 1
  pm_mount_root_sidecars "${root}" || return 1
  return 0
}

prepare_runtime_assets() {
  mkdir -p "${GAMEDIR}/game" "${GAMEDIR}/game/python-packages"
  : > "${PM_CONTAINER_MANIFEST}" || return 1

  detect_original_container || return 1

  pm_mount_container_root "${PM_ORIGINAL_BASE_ROOT}" || return 1

  if [ "${PM_ORIGINAL_CONTAINER_ROOT}" != "${PM_ORIGINAL_BASE_ROOT}" ]; then
    pm_mount_container_root "${PM_ORIGINAL_CONTAINER_ROOT}" || return 1
  fi

  if [ -d "${PM_ORIGINAL_CONTAINER_ROOT}/vnx/game" ]; then
    echo "Detected VNX staged game files; mounting vnx/game into active game."
    pm_mount_tree "${PM_ORIGINAL_CONTAINER_ROOT}/vnx/game" "${GAMEDIR}/game" "game" || return 1
  fi

  if [ ! -f "${GAMEDIR}/game/firstrun" ]; then
    : > "${GAMEDIR}/game/firstrun"
  fi

  for archive in audio.rpa images.rpa scripts.rpa fonts.rpa; do
    if [ ! -f "${GAMEDIR}/game/${archive}" ] && [ ! -L "${GAMEDIR}/game/${archive}" ]; then
      echo "Missing active archive after container mount: ${GAMEDIR}/game/${archive}"
      return 1
    fi
  done

  return 0
}

setup_gl() {
  local gl4es_dir="${GAMEDIR}/gl4es.${GL4ES_ARCH:-aarch64}"

  if [ "${PM_DISABLE_BUNDLED_GL:-0}" = "1" ]; then
    echo "PM_DISABLE_BUNDLED_GL=1, skipping bundled GL4ES."
    return 0
  fi

  if [ "${PM_USE_WESTON:-0}" != "0" ]; then
    echo "Westonpack is active; leaving bundled GL4ES out of the global loader path."
    return 0
  fi

  if [ -f "${controlfolder}/libgl_${CFW_NAME:-}.txt" ]; then
    # shellcheck source=/dev/null
    source "${controlfolder}/libgl_${CFW_NAME}.txt"
  elif [ -f "${controlfolder}/libgl_default.txt" ]; then
    # shellcheck source=/dev/null
    source "${controlfolder}/libgl_default.txt"
  fi

  if [ -d "${gl4es_dir}" ]; then
    LD_LIBRARY_PATH="${gl4es_dir}:${LD_LIBRARY_PATH:-}"
    if [ -f "${gl4es_dir}/libGL.so.1" ]; then
      export SDL_VIDEO_GL_DRIVER="${gl4es_dir}/libGL.so.1"
    fi
    if [ -f "${gl4es_dir}/libEGL.so.1" ]; then
      export SDL_VIDEO_EGL_DRIVER="${gl4es_dir}/libEGL.so.1"
    fi
    echo "Using bundled GL4ES from ${gl4es_dir}"
  else
    echo "No bundled GL4ES directory for ${GL4ES_ARCH:-unknown}; relying on firmware GL."
  fi
}

ensure_runtime_executable_bits() {
  local path

  for path in \
    "${GAMEDIR}/renpy.aarch64" \
    "${GAMEDIR}/renpy.armhf" \
    "${RUNTIME_ROOT}/renpy.sh" \
    "${RUNTIME_ROOT}/lib/py2-linux-aarch64/renpy" \
    "${RUNTIME_ROOT}/lib/py2-linux-aarch64/python" \
    "${RUNTIME_ROOT}/lib/py2-linux-aarch64/pythonw" \
    "${RUNTIME_ROOT}/lib/py2-linux-armv7l/renpy" \
    "${RUNTIME_ROOT}/lib/py2-linux-armv7l/python" \
    "${RUNTIME_ROOT}/lib/py2-linux-armv7l/pythonw"; do
    [ -e "${path}" ] || continue
    chmod +x "${path}" >/dev/null 2>&1 || true
  done
}

ensure_weston_runtime() {
  local runtime_file="${controlfolder}/libs/${WESTON_RUNTIME}.squashfs"

  if [ "${PM_USE_WESTON}" = "0" ]; then
    echo "PM_USE_WESTON=0, launching without Westonpack."
    return 0
  fi

  if [ "${PM_PREP_ONLY:-0}" = "1" ]; then
    return 0
  fi

  if [ ! -f "${runtime_file}" ]; then
    echo "Weston runtime is missing: ${runtime_file}"
    if [ -f "${controlfolder}/harbourmaster" ]; then
      echo "Requesting PortMaster runtime: ${WESTON_RUNTIME}.squashfs"
      pm_sudo "${controlfolder}/harbourmaster" --quiet --no-check runtime_check "${WESTON_RUNTIME}.squashfs" || return 1
    else
      echo "harbourmaster was not found; cannot request ${WESTON_RUNTIME}.squashfs."
      return 1
    fi
  fi

  if [ ! -f "${runtime_file}" ]; then
    echo "Weston runtime is still missing after runtime_check: ${runtime_file}"
    return 1
  fi

  local weston_runtime_dir="${XDG_RUNTIME_DIR:-/tmp/weston_runtime}"
  pm_sudo mkdir -p "${weston_runtime_dir}" || return 1
  pm_sudo chmod 700 "${weston_runtime_dir}" >/dev/null 2>&1 || true
  XDG_RUNTIME_DIR="${weston_runtime_dir}"
  export XDG_RUNTIME_DIR

  pm_sudo mkdir -p "${WESTON_DIR}" || return 1

  if [ "${PM_CAN_MOUNT:-Y}" != "N" ]; then
    pm_sudo umount "${WESTON_DIR}" >/dev/null 2>&1 || true
    if pm_sudo mount "${runtime_file}" "${WESTON_DIR}"; then
      PM_WESTON_MOUNTED="1"
      export PM_WESTON_MOUNTED
    else
      echo "Could not mount Weston runtime ${runtime_file} at ${WESTON_DIR}."
      return 1
    fi
  fi

  if [ ! -x "${WESTON_DIR}/westonwrap.sh" ]; then
    echo "westonwrap.sh is missing or not executable in ${WESTON_DIR}."
    return 1
  fi

  return 0
}

cleanup_weston_runtime() {
  if [ "${PM_WESTON_MOUNTED:-0}" = "1" ] && [ "${PM_CAN_MOUNT:-Y}" != "N" ]; then
    pm_sudo umount "${WESTON_DIR}" >/dev/null 2>&1 || true
  fi
}

configure_video_environment() {
  if [ "${PM_USE_WESTON}" != "0" ]; then
    WAYLAND_DISPLAY="${PM_WAYLAND_DISPLAY:-}"
    XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}"
    SDL_VIDEO_X11_FORCE_EGL="${PM_SDL_VIDEO_X11_FORCE_EGL:-0}"
    SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS=0
    unset SDL_VIDEO_GL_DRIVER SDL_VIDEO_EGL_DRIVER
    if [ -n "${PM_SDL_VIDEODRIVER+x}" ]; then
      SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER}"
      export SDL_VIDEODRIVER
    else
      unset SDL_VIDEODRIVER
    fi
  else
    SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER:-${SDL_VIDEODRIVER:-}}"
    export SDL_VIDEODRIVER
  fi

  export WAYLAND_DISPLAY XDG_SESSION_TYPE SDL_VIDEO_X11_FORCE_EGL SDL_VIDEO_MINIMIZE_ON_FOCUS_LOSS
  echo "Video env: SDL_VIDEODRIVER=${SDL_VIDEODRIVER:-auto}, DISPLAY=${DISPLAY:-unset}, WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-unset}, XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-unset}"
}

run_renpy_runtime() {
  local runtime_library_path="${PM_RUNTIME_LIBRARY_PATH:-${RUNTIME_ROOT}/lib/py2-linux-${RENPY_PLATFORM#linux-}:${RUNTIME_ROOT}/lib/python2.7:${GAMEDIR}}"
  local app_renderer="${RENPY_RENDERER:-gl2}"
  local app_performance_test="${RENPY_PERFORMANCE_TEST:-0}"
  local app_display="${DISPLAY:-:0}"
  local runtime_python="${RUNTIME_ROOT}/lib/py2-linux-${RENPY_PLATFORM#linux-}/python"
  local weston_runner="${GAMEDIR}/tools/pm_weston_run.sh"

  if [ -n "${PM_EXTRA_LIBRARY_PATH:-}" ]; then
    runtime_library_path="${runtime_library_path}:${PM_EXTRA_LIBRARY_PATH}"
  fi

  if [ "${PM_USE_WESTON}" != "0" ]; then
    echo "Using Westonpack GL/Crusty libraries; bundled GL4ES stays out of the Weston app path."
  fi

  if [ -n "${PM_RENPY_COMMAND:-}" ]; then
    echo "Ren'Py test command: ${PM_RENPY_COMMAND}"
  fi

  if [ "${PM_USE_WESTON}" != "0" ]; then
    echo "Launching via Westonpack ${WESTON_RUNTIME} (${WESTON_DIR}/westonwrap.sh)."
    echo "Wrapped app library path: ${runtime_library_path}"
    echo "Xwayland app display: ${app_display}"
    if [ -n "${PM_RENPY_COMMAND:-}" ]; then
      pm_sudo env \
        WRAPPED_LIBRARY_PATH="${runtime_library_path}" \
        LD_LIBRARY_PATH="" \
        PYTHONHOME="${PYTHONHOME:-${RUNTIME_ROOT}}" \
        PYTHONPATH="${PYTHONPATH:-${RUNTIME_ROOT}/lib/python2.7}" \
        RENPY_PLATFORM="${RENPY_PLATFORM:-linux-aarch64}" \
        RENPY_RENDERER="${app_renderer}" \
        RENPY_PERFORMANCE_TEST="${app_performance_test}" \
        RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}" \
        RENPY_LESS_MEMORY="${RENPY_LESS_MEMORY:-1}" \
        LIBGL_ES="${LIBGL_ES:-2}" \
        LIBGL_GL="${LIBGL_GL:-21}" \
        LIBGL_NOTEST="${LIBGL_NOTEST:-1}" \
        LIBGL_NOBANNER="${LIBGL_NOBANNER:-1}" \
        SDL_GAMECONTROLLERCONFIG="${SDL_GAMECONTROLLERCONFIG:-}" \
        DISPLAY="${app_display}" \
        XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}" \
        PM_SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER:-}" \
        PM_RENPY_PYTHON="${runtime_python}" \
        PM_X11_WAIT_SECONDS="${PM_X11_WAIT_SECONDS:-8}" \
        SDL_VIDEO_X11_FORCE_EGL="${SDL_VIDEO_X11_FORCE_EGL:-0}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        XDG_DATA_HOME="${CONFDIR}" \
        HOME="${CONFDIR}" \
        PORTMASTER=1 \
        PORTMASTER_MODE=1 \
        GAMEDIR="${GAMEDIR}" \
        CONFDIR="${CONFDIR}" \
        PM_MODS_DIR="${GAMEDIR}/mods" \
        PM_ORIGINAL_DIR="${PM_ORIGINAL_DIR:-${ORIGINAL_CONTAINER}}" \
        PM_LOGS_DIR="${LOGDIR}" \
        PM_ORIGINAL_BASE_ROOT="${PM_ORIGINAL_BASE_ROOT:-}" \
        PM_ORIGINAL_CONTAINER_ROOT="${PM_ORIGINAL_CONTAINER_ROOT:-${ORIGINAL_CONTAINER}}" \
        PM_DEVICE_PROFILE="${PM_DEVICE_PROFILE:-unknown}" \
        PM_DEVICE_HINTS="${PM_DEVICE_HINTS:-}" \
        PM_MEMORY_CLASS="${PM_MEMORY_CLASS:-unknown}" \
        PM_SCREEN_CLASS="${PM_SCREEN_CLASS:-unknown}" \
        PM_SMALL_SCREEN="${PM_SMALL_SCREEN:-0}" \
        PM_SCREEN_WIDTH="${PM_SCREEN_WIDTH:-}" \
        PM_SCREEN_HEIGHT="${PM_SCREEN_HEIGHT:-}" \
        PM_ASPECT_MODE="${PM_ASPECT_MODE:-auto}" \
        PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}" \
        PM_FULLSCREEN="${PM_FULLSCREEN:-1}" \
        PM_HANDHELD_MODE="${PM_HANDHELD_MODE:-1}" \
        PM_ENABLE_RENPY_PAD="${PM_ENABLE_RENPY_PAD:-1}" \
        PM_USE_VIRTUAL_KEYBOARD="${PM_USE_VIRTUAL_KEYBOARD:-1}" \
        PM_SHOW_TOUCH_QUICK_MENU="${PM_SHOW_TOUCH_QUICK_MENU:-0}" \
        PM_PERFORMANCE_PROFILE="${PM_PERFORMANCE_PROFILE:-balanced}" \
        PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-}" \
        PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-}" \
        PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-}" \
        PM_MENU_OPTIMIZE="${PM_MENU_OPTIMIZE:-0}" \
        PM_FRAMERATE="${PM_FRAMERATE:-}" \
        PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-}" \
        PM_DISABLE_GL_POWERSAVE="${PM_DISABLE_GL_POWERSAVE:-0}" \
        "${WESTON_DIR}/westonwrap.sh" headless noop kiosk crusty_glx_gl4es \
        XDG_DATA_HOME="${CONFDIR}" \
        HOME="${CONFDIR}" \
        PYTHONHOME="${PYTHONHOME:-${RUNTIME_ROOT}}" \
        PYTHONPATH="${PYTHONPATH:-${RUNTIME_ROOT}/lib/python2.7}" \
        RENPY_PLATFORM="${RENPY_PLATFORM:-linux-aarch64}" \
        RENPY_RENDERER="${app_renderer}" \
        RENPY_PERFORMANCE_TEST="${app_performance_test}" \
        RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}" \
        RENPY_LESS_MEMORY="${RENPY_LESS_MEMORY:-1}" \
        LIBGL_ES="${LIBGL_ES:-2}" \
        LIBGL_GL="${LIBGL_GL:-21}" \
        LIBGL_NOTEST="${LIBGL_NOTEST:-1}" \
        LIBGL_NOBANNER="${LIBGL_NOBANNER:-1}" \
        DISPLAY="${app_display}" \
        XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        PM_PERFORMANCE_PROFILE="${PM_PERFORMANCE_PROFILE:-balanced}" \
        PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-}" \
        PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-}" \
        PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-}" \
        PM_MENU_OPTIMIZE="${PM_MENU_OPTIMIZE:-0}" \
        PM_FRAMERATE="${PM_FRAMERATE:-}" \
        PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-}" \
        PM_USE_VIRTUAL_KEYBOARD="${PM_USE_VIRTUAL_KEYBOARD:-1}" \
        PM_SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER:-}" \
        PM_RENPY_PYTHON="${runtime_python}" \
        PM_X11_WAIT_SECONDS="${PM_X11_WAIT_SECONDS:-8}" \
        "${weston_runner}" "${RUNTIME_BIN}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}" "${PM_RENPY_COMMAND}"
    else
      pm_sudo env \
        WRAPPED_LIBRARY_PATH="${runtime_library_path}" \
        LD_LIBRARY_PATH="" \
        PYTHONHOME="${PYTHONHOME:-${RUNTIME_ROOT}}" \
        PYTHONPATH="${PYTHONPATH:-${RUNTIME_ROOT}/lib/python2.7}" \
        RENPY_PLATFORM="${RENPY_PLATFORM:-linux-aarch64}" \
        RENPY_RENDERER="${app_renderer}" \
        RENPY_PERFORMANCE_TEST="${app_performance_test}" \
        RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}" \
        RENPY_LESS_MEMORY="${RENPY_LESS_MEMORY:-1}" \
        LIBGL_ES="${LIBGL_ES:-2}" \
        LIBGL_GL="${LIBGL_GL:-21}" \
        LIBGL_NOTEST="${LIBGL_NOTEST:-1}" \
        LIBGL_NOBANNER="${LIBGL_NOBANNER:-1}" \
        SDL_GAMECONTROLLERCONFIG="${SDL_GAMECONTROLLERCONFIG:-}" \
        DISPLAY="${app_display}" \
        XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}" \
        PM_SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER:-}" \
        PM_RENPY_PYTHON="${runtime_python}" \
        PM_X11_WAIT_SECONDS="${PM_X11_WAIT_SECONDS:-8}" \
        SDL_VIDEO_X11_FORCE_EGL="${SDL_VIDEO_X11_FORCE_EGL:-0}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        XDG_DATA_HOME="${CONFDIR}" \
        HOME="${CONFDIR}" \
        PORTMASTER=1 \
        PORTMASTER_MODE=1 \
        GAMEDIR="${GAMEDIR}" \
        CONFDIR="${CONFDIR}" \
        PM_MODS_DIR="${GAMEDIR}/mods" \
        PM_ORIGINAL_DIR="${PM_ORIGINAL_DIR:-${ORIGINAL_CONTAINER}}" \
        PM_LOGS_DIR="${LOGDIR}" \
        PM_ORIGINAL_BASE_ROOT="${PM_ORIGINAL_BASE_ROOT:-}" \
        PM_ORIGINAL_CONTAINER_ROOT="${PM_ORIGINAL_CONTAINER_ROOT:-${ORIGINAL_CONTAINER}}" \
        PM_DEVICE_PROFILE="${PM_DEVICE_PROFILE:-unknown}" \
        PM_DEVICE_HINTS="${PM_DEVICE_HINTS:-}" \
        PM_MEMORY_CLASS="${PM_MEMORY_CLASS:-unknown}" \
        PM_SCREEN_CLASS="${PM_SCREEN_CLASS:-unknown}" \
        PM_SMALL_SCREEN="${PM_SMALL_SCREEN:-0}" \
        PM_SCREEN_WIDTH="${PM_SCREEN_WIDTH:-}" \
        PM_SCREEN_HEIGHT="${PM_SCREEN_HEIGHT:-}" \
        PM_ASPECT_MODE="${PM_ASPECT_MODE:-auto}" \
        PM_ASPECT_SCALE="${PM_ASPECT_SCALE:-fit}" \
        PM_FULLSCREEN="${PM_FULLSCREEN:-1}" \
        PM_HANDHELD_MODE="${PM_HANDHELD_MODE:-1}" \
        PM_ENABLE_RENPY_PAD="${PM_ENABLE_RENPY_PAD:-1}" \
        PM_USE_VIRTUAL_KEYBOARD="${PM_USE_VIRTUAL_KEYBOARD:-1}" \
        PM_SHOW_TOUCH_QUICK_MENU="${PM_SHOW_TOUCH_QUICK_MENU:-0}" \
        PM_PERFORMANCE_PROFILE="${PM_PERFORMANCE_PROFILE:-balanced}" \
        PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-}" \
        PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-}" \
        PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-}" \
        PM_MENU_OPTIMIZE="${PM_MENU_OPTIMIZE:-0}" \
        PM_FRAMERATE="${PM_FRAMERATE:-}" \
        PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-}" \
        PM_DISABLE_GL_POWERSAVE="${PM_DISABLE_GL_POWERSAVE:-0}" \
        "${WESTON_DIR}/westonwrap.sh" headless noop kiosk crusty_glx_gl4es \
        XDG_DATA_HOME="${CONFDIR}" \
        HOME="${CONFDIR}" \
        PYTHONHOME="${PYTHONHOME:-${RUNTIME_ROOT}}" \
        PYTHONPATH="${PYTHONPATH:-${RUNTIME_ROOT}/lib/python2.7}" \
        RENPY_PLATFORM="${RENPY_PLATFORM:-linux-aarch64}" \
        RENPY_RENDERER="${app_renderer}" \
        RENPY_PERFORMANCE_TEST="${app_performance_test}" \
        RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}" \
        RENPY_LESS_MEMORY="${RENPY_LESS_MEMORY:-1}" \
        LIBGL_ES="${LIBGL_ES:-2}" \
        LIBGL_GL="${LIBGL_GL:-21}" \
        LIBGL_NOTEST="${LIBGL_NOTEST:-1}" \
        LIBGL_NOBANNER="${LIBGL_NOBANNER:-1}" \
        DISPLAY="${app_display}" \
        XDG_SESSION_TYPE="${XDG_SESSION_TYPE:-x11}" \
        WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
        PM_PERFORMANCE_PROFILE="${PM_PERFORMANCE_PROFILE:-balanced}" \
        PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-}" \
        PM_IMAGE_CACHE_SIZE_MB="${PM_IMAGE_CACHE_SIZE_MB:-}" \
        PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-}" \
        PM_MENU_OPTIMIZE="${PM_MENU_OPTIMIZE:-0}" \
        PM_FRAMERATE="${PM_FRAMERATE:-}" \
        PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-}" \
        PM_USE_VIRTUAL_KEYBOARD="${PM_USE_VIRTUAL_KEYBOARD:-1}" \
        PM_SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER:-}" \
        PM_RENPY_PYTHON="${runtime_python}" \
        PM_X11_WAIT_SECONDS="${PM_X11_WAIT_SECONDS:-8}" \
        "${weston_runner}" "${RUNTIME_BIN}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}"
    fi
    return "$?"
  fi

  if [ -n "${PM_RENPY_COMMAND:-}" ]; then
    "${RUNTIME}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}" "${PM_RENPY_COMMAND}"
  else
    "${RUNTIME}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}"
  fi
}

pm_port_patch_version() {
  sed -n 's/^[[:space:]]*PM_PORT_VERSION[[:space:]]*=[[:space:]]*"\([^"]*\)".*/\1/p' "${GAMEDIR}/game/port_patch/pm_config.rpy" 2>/dev/null | head -n 1
}

clear_renpy_cache_if_needed() {
  local clear_mode="${PM_CLEAR_RENPY_CACHE:-auto}"
  local current_version=""
  local previous_version=""
  local stamp_file="${GAMEDIR}/persistent/port_patch_version.txt"

  if [ "${clear_mode}" = "0" ]; then
    echo "PM_CLEAR_RENPY_CACHE=0, keeping Ren'Py bytecode/cache."
    return 0
  fi

  current_version="$(pm_port_patch_version)"
  if [ -f "${stamp_file}" ]; then
    previous_version="$(cat "${stamp_file}" 2>/dev/null || true)"
  fi

  if [ "${clear_mode}" = "1" ] || [ -z "${current_version}" ] || [ "${previous_version}" != "${current_version}" ]; then
    echo "Clearing Ren'Py bytecode/cache for port patch version ${current_version:-unknown}."
    rm -f "${GAMEDIR}/game/port_patch/"*.rpyc >/dev/null 2>&1 || true
    rm -f "${GAMEDIR}/game/cache/"*.rpyb >/dev/null 2>&1 || true
    rm -f "${GAMEDIR}/log.txt" "${GAMEDIR}/traceback.txt" >/dev/null 2>&1 || true
    mkdir -p "$(dirname "${stamp_file}")" >/dev/null 2>&1 || true
    printf '%s\n' "${current_version}" > "${stamp_file}" 2>/dev/null || true
  else
    echo "Ren'Py bytecode/cache already matches port patch version ${current_version}."
  fi
}

detect_weston_inner_exit() {
  local code=""

  [ -f "${LOGFILE}" ] || return 1
  code="$(
    grep -E 'Your command has exited with exit code [0-9]+' "${LOGFILE}" 2>/dev/null \
      | tail -n 1 \
      | sed 's/.*exit code //; s/[^0-9].*//'
  )"

  if pm_is_uint "${code}" && [ "${code}" != "0" ]; then
    printf '%s\n' "${code}"
    return 0
  fi

  return 1
}

start_gptokeyb() {
  local gptokeyb_bin=""
  local gptokeyb_target=""

  if [ -n "${GPTOKEYB2:-}" ] && command -v "${GPTOKEYB2}" >/dev/null 2>&1; then
    gptokeyb_bin="${GPTOKEYB2}"
  elif [ -n "${GPTOKEYB:-}" ] && command -v "${GPTOKEYB}" >/dev/null 2>&1; then
    gptokeyb_bin="${GPTOKEYB}"
  elif [ -x "${controlfolder}/gptokeyb2" ]; then
    gptokeyb_bin="${controlfolder}/gptokeyb2"
  elif [ -x "${controlfolder}/gptokeyb" ]; then
    gptokeyb_bin="${controlfolder}/gptokeyb"
  elif command -v gptokeyb2 >/dev/null 2>&1; then
    gptokeyb_bin="gptokeyb2"
  elif command -v gptokeyb >/dev/null 2>&1; then
    gptokeyb_bin="gptokeyb"
  fi

  GPTOKEYB_PID=""
  if [ -n "${gptokeyb_bin}" ]; then
    gptokeyb_target="${PM_GPTOKEYB_TARGET:-$(basename "${RUNTIME_BIN}")}"
    echo "Starting ${gptokeyb_bin} with ${GAMEDIR}/ddlc.gptk"
    "${gptokeyb_bin}" "${gptokeyb_target}" -c "${GAMEDIR}/ddlc.gptk" textinput >/dev/null 2>&1 &
    GPTOKEYB_PID="$!"
  else
    echo "gptokeyb was not found; continuing without external gamepad mapping."
  fi
}

pm_timestamp() {
  date '+%Y-%m-%d %H:%M:%S %z' 2>/dev/null || date 2>/dev/null || printf '%s' "unknown-time"
}

pm_compact_log_lines() {
  sed 's/[[:space:]][[:space:]]*/ /g' | tr '\n' '|' | sed 's/|$//'
}

pm_error_summary() {
  local summary=""

  if [ -f "${LOGFILE}" ]; then
    summary="$(
      tail -n 160 "${LOGFILE}" 2>/dev/null \
        | grep -Ei 'error|exception|traceback|failed|fail|missing|unsupported|could not|cannot|segmentation|segfault|fatal|exit code|not found|permission denied|glibc|importerror|runtimeerror|abort' 2>/dev/null \
        | tail -n 12 \
        | pm_compact_log_lines
    )"

    if [ -z "${summary}" ]; then
      summary="$(tail -n 20 "${LOGFILE}" 2>/dev/null | pm_compact_log_lines)"
    fi
  fi

  if [ -z "${summary}" ]; then
    summary="No error output captured. The process may have been killed before it could write details."
  fi

  printf '%s' "${summary}"
}

append_crash_log() {
  local code="$1"
  local reason="${2:-}"
  local timestamp
  local summary

  timestamp="$(pm_timestamp)"
  summary="$(pm_error_summary)"

  if [ -n "${reason}" ]; then
    summary="${reason}; ${summary}"
  fi

  {
    printf '"%s" (exit code %s) %s\n' "${timestamp}" "${code}" "${summary}"
    printf '"%s" (full log) %s\n' "${timestamp}" "${LOGFILE}"
  } >> "${CRASHLOG}" 2>/dev/null || true
}

pm_signal_crash() {
  local code="$1"
  local signal_name="$2"

  append_crash_log "${code}" "Wrapper interrupted by ${signal_name}."
  pm_tty_message "DDLC failed.
Check ddlc/logs/log.txt."
  exit "${code}"
}

finish_wrapper() {
  local code="$1"
  local reason="${2:-}"

  if [ -n "${GPTOKEYB_PID:-}" ]; then
    kill "${GPTOKEYB_PID}" >/dev/null 2>&1 || true
  fi

  if type pm_finish >/dev/null 2>&1; then
    pm_finish
  fi

  cleanup_weston_runtime

  if [ "${code}" = "0" ]; then
    pm_tty_clear
  else
    append_crash_log "${code}" "${reason}"
    pm_tty_message "DDLC failed.
Check ddlc/logs/log.txt."
  fi

  echo "Wrapper finished with exit code ${code}."
  exit "${code}"
}

trap 'pm_signal_crash 129 SIGHUP' HUP
trap 'pm_signal_crash 130 SIGINT' INT
trap 'pm_signal_crash 143 SIGTERM' TERM

load_user_configs
detect_memory_class
detect_device_profile
apply_device_defaults
detect_display_mode
detect_runtime || finish_wrapper 1

export PORTMASTER=1
export GAMEDIR
export CONFDIR
export PM_SAVEDIR
export HOME="${CONFDIR}"
export XDG_DATA_HOME="${CONFDIR}"
export SDL_GAMECONTROLLERCONFIG="${sdl_controllerconfig:-${SDL_GAMECONTROLLERCONFIG:-}}"
export TEXTINPUTINTERACTIVE="Y"
export PYTHONHOME="${RUNTIME_ROOT}"
export PYTHONPATH="${RUNTIME_ROOT}/lib/python2.7"
export RENPY_NO_STEAM=1

echo "Performance profile: ${PM_PERFORMANCE_PROFILE:-balanced}, cache ${PM_IMAGE_CACHE_SIZE:-auto}, predict ${PM_PREDICT_STATEMENTS:-auto}, GL FPS ${PM_GL_FRAMERATE:-auto}"
echo "Renderer hints: RENPY_RENDERER=${RENPY_RENDERER:-auto}, RENPY_GL_VSYNC=${RENPY_GL_VSYNC:-auto}"

LD_LIBRARY_PATH="${RUNTIME_ROOT}/lib/py2-linux-${RENPY_PLATFORM#linux-}:${RUNTIME_ROOT}/lib/python2.7:${GAMEDIR}:${LD_LIBRARY_PATH:-}"
setup_gl
export LD_LIBRARY_PATH
ensure_runtime_executable_bits

if [ ! -d "${RUNTIME_ROOT}/renpy" ] || [ ! -f "${RUNTIME_ROOT}/renpy.py" ]; then
  echo "Bundled Ren'Py runtime is incomplete: ${RUNTIME_ROOT}"
  finish_wrapper 1
fi

if [ ! -x "${RUNTIME}" ]; then
  echo "Runtime launcher is missing or not executable: ${RUNTIME}"
  finish_wrapper 1
fi

if [ ! -x "${RUNTIME_BIN}" ]; then
  echo "Runtime binary is missing or not executable: ${RUNTIME_BIN}"
  finish_wrapper 1
fi

if [ "${SKIP_ASSET_CHECK:-0}" != "1" ]; then
  if [ ! -f "${GAMEDIR}/tools/check_assets.sh" ]; then
    echo "Asset checker is missing: ${GAMEDIR}/tools/check_assets.sh"
    finish_wrapper 1
  fi
  if ! sh "${GAMEDIR}/tools/check_assets.sh" "${GAMEDIR}"; then
    echo "Asset validation failed. Copy your original DDLC files into ${GAMEDIR}/original."
    finish_wrapper 1
  fi
else
  echo "SKIP_ASSET_CHECK=1, skipping required asset validation."
fi

clean_previous_container_overlay

if ! prepare_runtime_assets; then
  echo "Could not prepare runtime assets."
  finish_wrapper 1
fi

clear_renpy_cache_if_needed

if [ "${PM_PREP_ONLY:-0}" = "1" ]; then
  echo "PM_PREP_ONLY=1, stopping after container mount."
  finish_wrapper 0
fi

configure_video_environment

if [ "${PM_USE_WESTON}" = "0" ] && type pm_platform_helper >/dev/null 2>&1; then
  echo "Running pm_platform_helper for ${RUNTIME_BIN}"
  pm_platform_helper "${RUNTIME_BIN}"
elif [ "${PM_USE_WESTON}" != "0" ]; then
  echo "Using Westonpack video wrapper; skipping pm_platform_helper."
fi

if ! ensure_weston_runtime; then
  echo "Could not prepare Weston runtime; this Ren'Py build needs an X11/Weston video layer."
  finish_wrapper 1 "Weston runtime could not be prepared."
fi

start_gptokeyb

cd "${GAMEDIR}" || finish_wrapper 1
echo "Launching Ren'Py 7.5.3 ARM runtime..."
run_renpy_runtime
RESULT="$?"
WESTON_INNER_RESULT="$(detect_weston_inner_exit || true)"
if pm_is_uint "${WESTON_INNER_RESULT}" && [ "${WESTON_INNER_RESULT}" != "0" ]; then
  echo "Westonpack reported inner command exit code ${WESTON_INNER_RESULT}."
  RESULT="${WESTON_INNER_RESULT}"
fi
if [ "${RESULT}" = "0" ]; then
  finish_wrapper 0
else
  finish_wrapper "${RESULT}" "Ren'Py runtime exited with code ${RESULT}."
fi
