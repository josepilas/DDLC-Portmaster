#!/bin/sh

set -u

if [ "${PM_SDL_VIDEODRIVER:-}" != "" ]; then
  export SDL_VIDEODRIVER="${PM_SDL_VIDEODRIVER}"
  echo "SDL video driver forced by PM_SDL_VIDEODRIVER=${SDL_VIDEODRIVER}"
else
  unset SDL_VIDEODRIVER
  echo "SDL video driver: auto"
fi

unset SDL_VIDEO_GL_DRIVER SDL_VIDEO_EGL_DRIVER

if [ "${PM_X11_PREWARM:-1}" != "0" ] && [ -n "${DISPLAY:-}" ] && [ -x "${PM_RENPY_PYTHON:-}" ]; then
  wait_seconds="${PM_X11_WAIT_SECONDS:-8}"
  attempts="${wait_seconds}"
  [ "${attempts}" -lt 1 ] && attempts=1
  probe="${GAMEDIR:-.}/tools/pm_x11_probe.py"

  echo "Waiting for Xwayland display ${DISPLAY} (${wait_seconds}s max)."
  i=1
  while [ "${i}" -le "${attempts}" ]; do
    if "${PM_RENPY_PYTHON}" "${probe}" >/dev/null 2>&1; then
      echo "Xwayland display ${DISPLAY} accepted a connection."
      break
    fi
    sleep 1
    i=$((i + 1))
  done

  if [ "${i}" -gt "${attempts}" ]; then
    echo "Xwayland probe did not connect before timeout; launching Ren'Py anyway."
    PM_X11_PROBE_VERBOSE=1 "${PM_RENPY_PYTHON}" "${probe}" || true
  fi
else
  echo "Skipping Xwayland probe: DISPLAY=${DISPLAY:-unset}, PM_RENPY_PYTHON=${PM_RENPY_PYTHON:-unset}."
fi

exec "$@"
