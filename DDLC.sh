#!/bin/bash

set -u

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

mkdir -p "${CONFDIR}" "${LOGDIR}" "${PM_SAVEDIR}" "${GAMEDIR}/persistent"

LOGFILE="${LOGDIR}/ddlc-portmaster.log"
: > "${LOGFILE}"
if [ -e /dev/fd/1 ] || [ -d /dev/fd ]; then
  exec > >(tee -a "${LOGFILE}") 2>&1
else
  exec >> "${LOGFILE}" 2>&1
  echo "No /dev/fd available; logging to ${LOGFILE} only."
fi

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
    PM_SHOW_TOUCH_QUICK_MENU="${PM_SHOW_TOUCH_QUICK_MENU:-0}"
    PM_SMALL_SCREEN="${PM_SMALL_SCREEN:-1}"
    PM_GL_FRAMERATE="${PM_GL_FRAMERATE:-30}"
    PM_FRAMERATE="${PM_FRAMERATE:-30}"
    RENPY_RENDERER="${RENPY_RENDERER:-gl2}"
    RENPY_GL_VSYNC="${RENPY_GL_VSYNC:-1}"

    if [ -z "${PM_PERFORMANCE_PROFILE:-}" ]; then
      if [ "${PM_MEMORY_CLASS}" = "256mb" ] || [ "${PM_MEMORY_CLASS}" = "512mb" ]; then
        PM_PERFORMANCE_PROFILE="low"
      else
        PM_PERFORMANCE_PROFILE="balanced"
      fi
    fi

    if [ "${PM_MEMORY_CLASS}" = "256mb" ]; then
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-16}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-8}"
    elif [ "${PM_MEMORY_CLASS}" = "512mb" ]; then
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-24}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-12}"
    else
      PM_IMAGE_CACHE_SIZE="${PM_IMAGE_CACHE_SIZE:-48}"
      PM_PREDICT_STATEMENTS="${PM_PREDICT_STATEMENTS:-28}"
    fi
  fi

  export PM_DEVICE_FALLBACK_WIDTH PM_DEVICE_FALLBACK_HEIGHT
  export PM_HANDHELD_MODE PM_ENABLE_RENPY_PAD PM_SHOW_TOUCH_QUICK_MENU PM_SMALL_SCREEN
  export PM_PERFORMANCE_PROFILE PM_IMAGE_CACHE_SIZE PM_PREDICT_STATEMENTS
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

prepare_runtime_assets() {
  local archive
  local src
  local dst

  mkdir -p "${GAMEDIR}/game" "${GAMEDIR}/game/python-packages"

  for archive in audio.rpa images.rpa scripts.rpa fonts.rpa; do
    src="${GAMEDIR}/original/game/${archive}"
    dst="${GAMEDIR}/game/${archive}"
    if [ ! -f "${src}" ]; then
      echo "Missing required archive during runtime prep: ${src}"
      return 1
    fi

    rm -f "${dst}" 2>/dev/null || true
    if ln -s "../original/game/${archive}" "${dst}" 2>/dev/null; then
      echo "Linked ${archive}"
    else
      echo "Symlink failed for ${archive}; copying instead."
      cp "${src}" "${dst}" || return 1
    fi
  done

  if [ ! -f "${GAMEDIR}/game/firstrun" ]; then
    : > "${GAMEDIR}/game/firstrun"
  fi

  return 0
}

setup_gl() {
  local gl4es_dir="${GAMEDIR}/gl4es.${GL4ES_ARCH:-aarch64}"

  if [ "${PM_DISABLE_BUNDLED_GL:-0}" = "1" ]; then
    echo "PM_DISABLE_BUNDLED_GL=1, skipping bundled GL4ES."
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

start_gptokeyb() {
  local gptokeyb_bin=""

  if [ -n "${GPTOKEYB2:-}" ] && command -v "${GPTOKEYB2}" >/dev/null 2>&1; then
    gptokeyb_bin="${GPTOKEYB2}"
  elif [ -n "${GPTOKEYB:-}" ] && command -v "${GPTOKEYB}" >/dev/null 2>&1; then
    gptokeyb_bin="${GPTOKEYB}"
  elif command -v gptokeyb2 >/dev/null 2>&1; then
    gptokeyb_bin="gptokeyb2"
  elif command -v gptokeyb >/dev/null 2>&1; then
    gptokeyb_bin="gptokeyb"
  fi

  GPTOKEYB_PID=""
  if [ -n "${gptokeyb_bin}" ]; then
    echo "Starting ${gptokeyb_bin} with ${GAMEDIR}/ddlc.gptk"
    "${gptokeyb_bin}" "${RUNTIME_BIN}" -c "${GAMEDIR}/ddlc.gptk" >/dev/null 2>&1 &
    GPTOKEYB_PID="$!"
  else
    echo "gptokeyb was not found; continuing without external gamepad mapping."
  fi
}

finish_wrapper() {
  local code="$1"

  if [ -n "${GPTOKEYB_PID:-}" ]; then
    kill "${GPTOKEYB_PID}" >/dev/null 2>&1 || true
  fi

  if type pm_finish >/dev/null 2>&1; then
    pm_finish
  fi

  echo "Wrapper finished with exit code ${code}."
  exit "${code}"
}

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
export PYTHONHOME="${RUNTIME_ROOT}"
export PYTHONPATH="${RUNTIME_ROOT}/lib/python2.7"
export RENPY_NO_STEAM=1

echo "Performance profile: ${PM_PERFORMANCE_PROFILE:-balanced}, cache ${PM_IMAGE_CACHE_SIZE:-auto}, predict ${PM_PREDICT_STATEMENTS:-auto}, GL FPS ${PM_GL_FRAMERATE:-auto}"
echo "Renderer hints: RENPY_RENDERER=${RENPY_RENDERER:-auto}, RENPY_GL_VSYNC=${RENPY_GL_VSYNC:-auto}"

LD_LIBRARY_PATH="${RUNTIME_ROOT}/lib/py2-linux-${RENPY_PLATFORM#linux-}:${RUNTIME_ROOT}/lib/python2.7:${GAMEDIR}:${LD_LIBRARY_PATH:-}"
setup_gl
export LD_LIBRARY_PATH

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

if ! prepare_runtime_assets; then
  echo "Could not prepare runtime assets."
  finish_wrapper 1
fi

if type pm_platform_helper >/dev/null 2>&1; then
  pm_platform_helper "${RUNTIME_BIN}"
fi

start_gptokeyb

cd "${GAMEDIR}" || finish_wrapper 1
echo "Launching Ren'Py 7.5.3 ARM runtime..."
if [ -n "${PM_RENPY_COMMAND:-}" ]; then
  echo "Ren'Py test command: ${PM_RENPY_COMMAND}"
  "${RUNTIME}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}" "${PM_RENPY_COMMAND}"
else
  "${RUNTIME}" --savedir "${PM_SAVEDIR}" "${GAMEDIR}"
fi
RESULT="$?"
finish_wrapper "${RESULT}"
