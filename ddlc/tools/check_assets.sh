#!/bin/sh

set -u

GAMEDIR="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
MANIFEST="${GAMEDIR}/tools/asset_manifest.json"
ORIGINAL_CONTAINER="${PM_ORIGINAL_CONTAINER:-${GAMEDIR}/original}"

if [ "${SKIP_ASSET_CHECK:-0}" = "1" ]; then
    echo "SKIP_ASSET_CHECK=1, skipping asset validation."
    exit 0
fi

echo "Checking required DDLC assets..."
echo "Game dir: ${GAMEDIR}"
echo "Original container: ${ORIGINAL_CONTAINER}"

if [ ! -f "${MANIFEST}" ]; then
    echo "Warning: manifest not found at ${MANIFEST}; using built-in required paths."
fi

REQUIRED_FILES="
game/audio.rpa
game/images.rpa
game/scripts.rpa
game/fonts.rpa
characters/monika.chr
characters/sayori.chr
characters/natsuki.chr
characters/yuri.chr
"

container_has_required_assets() {
    root="$1"
    for relpath in ${REQUIRED_FILES}; do
        [ -f "${root}/${relpath}" ] || return 1
    done
    return 0
}

resolve_original_root() {
    entry=""

    if container_has_required_assets "${ORIGINAL_CONTAINER}"; then
        printf '%s\n' "${ORIGINAL_CONTAINER}"
        return 0
    fi

    for entry in "${ORIGINAL_CONTAINER}"/*; do
        [ -d "${entry}" ] || continue
        if container_has_required_assets "${entry}"; then
            printf '%s\n' "${entry}"
            return 0
        fi
    done

    return 1
}

if ! ORIGINAL_ROOT="$(resolve_original_root)"; then
    ORIGINAL_ROOT="${ORIGINAL_CONTAINER}"
fi

echo "Detected asset root: ${ORIGINAL_ROOT}"

missing=0
warnings=0

check_file() {
    relpath="$1"
    expected_size="$2"
    fullpath="${ORIGINAL_ROOT}/${relpath}"
    if [ ! -f "${fullpath}" ]; then
        echo "Missing: original/${relpath}"
        missing=1
    else
        echo "Found: original/${relpath}"
        if [ -n "${expected_size}" ]; then
            actual_size="$(wc -c < "${fullpath}" 2>/dev/null | tr -d '[:space:]')"
            if [ -n "${actual_size}" ] && [ "${actual_size}" != "${expected_size}" ]; then
                echo "Warning: original/${relpath} size is ${actual_size}; expected ${expected_size} for DDLC 1.1.1."
                warnings=1
            fi
        fi
    fi
}

check_file "game/audio.rpa" "65683283"
check_file "game/images.rpa" "137750644"
check_file "game/scripts.rpa" "2708885"
check_file "game/fonts.rpa" "1831581"
check_file "characters/monika.chr" "137604"
check_file "characters/sayori.chr" "59621"
check_file "characters/natsuki.chr" "44793"
check_file "characters/yuri.chr" "30340"

if [ "${missing}" -ne 0 ]; then
    echo ""
    echo "Required assets are missing."
    echo "Extract or copy your DDLC root into:"
    echo "  ${ORIGINAL_CONTAINER}"
    echo "No assets will be downloaded by this wrapper."
    exit 1
fi

if [ "${warnings}" -ne 0 ]; then
    echo ""
    echo "Asset size warnings were found. The wrapper will continue, but DDLC 1.1.1 assets are recommended."
fi

echo "All required DDLC assets were found."
exit 0
