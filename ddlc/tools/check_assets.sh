#!/bin/sh

set -u

GAMEDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="${GAMEDIR}/tools/asset_manifest.json"

if [ "${SKIP_ASSET_CHECK:-0}" = "1" ]; then
    echo "SKIP_ASSET_CHECK=1, skipping asset validation."
    exit 0
fi

echo "Checking required DDLC assets..."
echo "Game dir: ${GAMEDIR}"

if [ ! -f "${MANIFEST}" ]; then
    echo "Warning: manifest not found at ${MANIFEST}; using built-in required paths."
fi

REQUIRED_FILES="
original/game/audio.rpa
original/game/images.rpa
original/game/scripts.rpa
original/game/fonts.rpa
original/characters/monika.chr
original/characters/sayori.chr
original/characters/natsuki.chr
original/characters/yuri.chr
"

missing=0
warnings=0

check_file() {
    relpath="$1"
    expected_size="$2"
    fullpath="${GAMEDIR}/${relpath}"
    if [ ! -f "${fullpath}" ]; then
        echo "Missing: ddlc/${relpath}"
        missing=1
    else
        echo "Found: ddlc/${relpath}"
        if [ -n "${expected_size}" ]; then
            actual_size="$(wc -c < "${fullpath}" 2>/dev/null | tr -d '[:space:]')"
            if [ -n "${actual_size}" ] && [ "${actual_size}" != "${expected_size}" ]; then
                echo "Warning: ddlc/${relpath} size is ${actual_size}; expected ${expected_size} for DDLC 1.1.1."
                warnings=1
            fi
        fi
    fi
}

check_file "original/game/audio.rpa" "65683283"
check_file "original/game/images.rpa" "137750644"
check_file "original/game/scripts.rpa" "2708885"
check_file "original/game/fonts.rpa" "1831581"
check_file "original/characters/monika.chr" "137604"
check_file "original/characters/sayori.chr" "59621"
check_file "original/characters/natsuki.chr" "44793"
check_file "original/characters/yuri.chr" "30340"

if [ "${missing}" -ne 0 ]; then
    echo ""
    echo "Required assets are missing."
    echo "Copy files from your original DDLC installation into:"
    echo "  ${GAMEDIR}/original/game"
    echo "  ${GAMEDIR}/original/characters"
    echo "No assets will be downloaded by this wrapper."
    exit 1
fi

if [ "${warnings}" -ne 0 ]; then
    echo ""
    echo "Asset size warnings were found. The wrapper will continue, but DDLC 1.1.1 assets are recommended."
fi

echo "All required DDLC assets were found."
exit 0
