# DDLC PortMaster Compatibility Wrapper

Unofficial, asset-free PortMaster wrapper for running a user-owned copy of
Doki Doki Literature Club on handheld Linux devices.

This package does not include original DDLC assets, official DDLC images,
audio, fonts, scripts, or `.chr` files. The player must provide their own
legally obtained DDLC 1.1.1 files.

## What Is Included

- `DDLC.sh` PortMaster launcher.
- `port.json`, `gameinfo.xml`, and `screenshot.png`.
- Bundled Ren'Py 7.5.3 ARM runtime for `aarch64` and `armhf`.
- Bundled GL4ES libraries.
- R36S/R36H/RK3326 handheld profiles.
- Automatic 4:3 / 16:9 display handling.
- Gamepad-friendly virtual keyboard.
- Controller quick panel.
- Virtual in-game file manager for the `characters` folder.
- Virtual character deletion layer that never deletes real files.
- Local save/persistent routing inside `ddlc/saves`.
- Asset validation tools in `ddlc/tools`.

## What Is Not Included

- Original DDLC `.rpa` archives.
- Original DDLC `.chr` character files.
- Any automatic asset downloader.
- Development-only desktop test scripts.
- Internal audit/dev notes.

## Install

Install through PortMaster if your firmware supports ZIP installation, or copy
the extracted files so the layout on the device looks like this:

```text
/roms/ports/DDLC.sh
/roms/ports/ddlc/
```

Some firmwares use a different ports directory, but the launcher expects
`DDLC.sh` and the `ddlc` folder to stay next to each other.

## Add Your DDLC Files

Copy these files from your own DDLC 1.1.1 PC copy into the port folder:

```text
ddlc/original/game/audio.rpa
ddlc/original/game/images.rpa
ddlc/original/game/scripts.rpa
ddlc/original/game/fonts.rpa
ddlc/original/characters/monika.chr
ddlc/original/characters/sayori.chr
ddlc/original/characters/natsuki.chr
ddlc/original/characters/yuri.chr
```

Expected DDLC 1.1.1 sizes:

```text
audio.rpa       65683283 bytes
images.rpa     137750644 bytes
scripts.rpa    2708885 bytes
fonts.rpa      1831581 bytes
monika.chr     137604 bytes
sayori.chr     59621 bytes
natsuki.chr    44793 bytes
yuri.chr       30340 bytes
```

The checker warns about size mismatches but only fails when required files are
missing.

Run this on-device if you want to verify the files before launching:

```sh
sh ddlc/tools/check_assets.sh ddlc
```

## Controls

Default `ddlc.gptk` mapping:

```text
A       Enter / select / advance text
B       Backspace
D-Pad   Arrow navigation
Start   Escape / Ren'Py menu
Select  F9 / quick panel
X       F10 / file manager, or Space in virtual keyboard
Y       H / hide dialogue, or case toggle in virtual keyboard
L/R     PageUp/PageDown
```

The quick panel opens with Select/F9 and exposes History, Settings, Save, Load,
Auto, Skip, Files, and Close.

The virtual keyboard opens automatically when the game asks for typed input.

## File Manager And Characters

The in-game file manager is a compatibility screen for handheld play. It shows
the `characters` folder and supports deleting/restoring character files in the
story sense.

It does not delete files from the SD card. Deletions are stored in Ren'Py
persistent data as virtual state.

## Display Modes

DDLC internally stays on its original 1280x720 virtual canvas. The launcher
detects the handheld display and exports:

```text
PM_SCREEN_WIDTH
PM_SCREEN_HEIGHT
PM_ASPECT_MODE=auto|4:3|16:9
PM_ASPECT_SCALE=fit|stretch
PM_FULLSCREEN=0|1
```

Default behavior:

- 16:9 devices use normal DDLC widescreen output.
- 4:3 devices use safe fit scaling to avoid cropping dialogue or UI.
- R36S defaults to 640x480 4:3.
- Common R36H defaults to screen detection with 640x480 fallback.
- `PM_DEVICE_PROFILE=r36h_wide` is available for true wide R36H variants.

## Performance Profiles

The launcher tunes low-power RK3326 handhelds conservatively:

```text
PM_HANDHELD_MODE=1
PM_ENABLE_RENPY_PAD=1
PM_SHOW_TOUCH_QUICK_MENU=0
PM_GL_FRAMERATE=30
PM_FRAMERATE=30
RENPY_RENDERER=gl2
RENPY_GL_VSYNC=1
```

Memory-sensitive defaults are applied for 256MB/512MB/1GB systems. Override
with:

```text
PM_PERFORMANCE_PROFILE=low|balanced|quality
```

## Saves

Saves and persistent data are stored in:

```text
ddlc/saves
```

The launcher passes Ren'Py `--savedir` explicitly so data stays inside the port
folder.

## Known Limitations

- Final hardware validation is still required on real R36S/R36H devices.
- QEMU ARM64 smoke testing passed, but it was headless and did not test real
  GPU, audio, display, or physical controls.
- The `aarch64` runtime path has been smoke-tested; `armhf` still needs real
  device/rootfs testing.
- The 4:3 mode is safe compatibility scaling, not a full native 4:3 rewrite of
  every DDLC screen.
- `gptokeyb` button names may need firmware-specific adjustment on some devices.

## Troubleshooting

If the game exits immediately, check:

```text
ddlc/logs/ddlc-portmaster.log
```

Common causes:

- Missing `.rpa` or `.chr` files in `ddlc/original`.
- Files from a different DDLC version.
- Runtime file permissions lost during manual copy.
- Firmware GL/SDL differences that require a GL4ES tweak.

For manual permission repair on Linux:

```sh
chmod +x DDLC.sh ddlc/renpy.aarch64 ddlc/renpy.armhf
```

## Legal Notes

This is an unofficial compatibility wrapper. Original Doki Doki Literature Club
assets, trademarks, characters, and story content belong to their respective
rights holders and are not included here.

Users should provide their own legally obtained DDLC copy. Review Team
Salvato's current IP and mod distribution guidance before redistributing a
finished package.

Runtime components:

- Ren'Py 7.5.3 ARM SDK runtime, license in `ddlc/licenses/RenPy-LICENSE.txt`.
- GL4ES libraries, license in `ddlc/licenses/LICENSE-gl4es.txt`.
