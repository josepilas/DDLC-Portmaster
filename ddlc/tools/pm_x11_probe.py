import ctypes
import os
import sys


display = os.environ.get("DISPLAY", "")
if not display:
    sys.exit(1)

try:
    x11 = ctypes.CDLL("libX11.so.6")
    x11.XOpenDisplay.argtypes = [ctypes.c_char_p]
    x11.XOpenDisplay.restype = ctypes.c_void_p
    x11.XCloseDisplay.argtypes = [ctypes.c_void_p]
    x11.XCloseDisplay.restype = ctypes.c_int

    handle = x11.XOpenDisplay(display.encode("ascii"))
    if not handle:
        if os.environ.get("PM_X11_PROBE_VERBOSE"):
            sys.stderr.write("XOpenDisplay returned NULL for DISPLAY={0}\n".format(display))
        sys.exit(1)

    x11.XCloseDisplay(handle)
except Exception as exc:
    sys.stderr.write("X11 probe failed: {0}\n".format(exc))
    sys.exit(2)

sys.exit(0)
