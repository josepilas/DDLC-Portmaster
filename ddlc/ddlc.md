# DDLC PortMaster Compatibility Wrapper

Unofficial, asset-free PortMaster wrapper for running a user-owned copy of
Doki Doki Literature Club on handheld Linux devices.

This package does not include original DDLC assets, official DDLC images,
audio, fonts, scripts, or `.chr` files. The player must provide their own
legally obtained DDLC 1.1.1 files.

## What Is Included

- `DDLC.sh` PortMaster launcher.
- PortMaster metadata inside `ddlc/`: `port.json`, `gameinfo.xml`, `screenshot.png`, and `ddlc.md`.
- Bundled Ren'Py 7.5.3 ARM runtime for `aarch64` and `armhf`.
- Bundled GL4ES libraries.
- PortMaster Westonpack runtime (`weston_pkg_0.2.squashfs`) for the X11/GL4ES
  video layer required by the bundled Ren'Py runtime.
- R36S/R36H/RK3326 handheld profiles.
- Automatic 4:3 / 16:9 display handling.
- Gamepad-friendly virtual keyboard.
- Controller quick panel.
- Virtual in-game file manager for the `characters` folder.
- Virtual character deletion layer that never deletes real files.
- `ddlc/original` root-container support for user-supplied games, mods, and translations.
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

The PortMaster-style release ZIP for this package is `ddlc.zip`.

Some firmwares use a different ports directory, but the launcher expects
`DDLC.sh` and the `ddlc` folder to stay next to each other.

## Add Your DDLC Files

Use `ddlc/original` as a container for the root of your DDLC installation.
That means the same layout you would use on PC goes inside `original`.

Recommended layout:

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

Also supported: extracting the official ZIP so the root folder remains one
level below `original`:

```text
ddlc/original/DDLC-1.1.1-pc/game/audio.rpa
ddlc/original/DDLC-1.1.1-pc/characters/monika.chr
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

## Mods And Translations

Mods and translations should be applied inside `ddlc/original`, the same way
they are applied to a normal DDLC PC folder.

Example for a direct translated/modded root:

```text
ddlc/original/game/scripts.rpa
ddlc/original/game/vnx.rpx
ddlc/original/game/vnxsurvival.rpyc
ddlc/original/vnx/
```

Example when starting from the official ZIP plus a VNX translation ZIP:

```text
ddlc/original/DDLC-1.1.1-pc/game/audio.rpa
ddlc/original/DDLC-1.1.1-pc/game/images.rpa
ddlc/original/DDLC-1.1.1-pc/game/scripts.rpa
ddlc/original/DDLC-1.1.1-pc/game/fonts.rpa
ddlc/original/DDLC-1.1.1-pc/characters/
ddlc/original/game/vnxsurvival.rpyc
ddlc/original/vnx/
```

At launch, the wrapper detects the valid DDLC asset root, mounts its `game/`
folder into the active runtime, then mounts files placed directly in
`ddlc/original/game`. If `ddlc/original/vnx/game` exists, it is also mounted
into the active `game` folder automatically. This lets VNX-style translations
work without manually separating files.

This package also adds ARM runtime support for VNX/RPE `.rpx` archives. Mods
that require unrelated custom native libraries or a newer Python 3/Ren'Py 8
runtime may still be incompatible.

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

## User Config File

Most player-facing options are controlled by:

```text
ddlc/user_configs.txt
```

Edit it on a computer, then put the card back in the handheld and launch the
port. The file uses numbered choices such as `resolution_mode=1`,
`performance_mode=0`, and `menu_optimization=0`; each option is explained in
the file itself. If the file is deleted, the launcher recreates a default copy.

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
PM_MENU_OPTIMIZE=0|1
PM_IMAGE_CACHE_SIZE=24
PM_IMAGE_CACHE_SIZE_MB=96
PM_PREDICT_STATEMENTS=12
```

On RK3326/R36 class devices, `PM_MENU_OPTIMIZE=1` is enabled by default. It
keeps DDLC gameplay intact while replacing the animated menu background and
particle overlay with static equivalents for smoother save/load/settings menus.

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
ddlc/logs/log.txt
ddlc/logs/ddlc-portmaster.log
```

`log.txt` appends one short crash entry per failed launch, including the exact
date/time, exit code, and error summary. `ddlc-portmaster.log` is replaced each
run and contains the full output from the latest launch attempt.

Common causes:

- Missing `.rpa` or `.chr` files in `ddlc/original`.
- Files from a different DDLC version.
- Mod/translation files copied outside `ddlc/original`.
- Runtime file permissions lost during manual copy.
- Firmware GL/SDL differences that require a GL4ES tweak.
- Missing PortMaster Westonpack runtime. The port declares
  `weston_pkg_0.2.squashfs`, and the launcher will try to request it through
  HarbourMaster when possible.

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
