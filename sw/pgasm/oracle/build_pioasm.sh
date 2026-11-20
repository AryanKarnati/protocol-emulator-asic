#!/usr/bin/env bash
# Build the official Raspberry Pi pioasm from a pinned pico-sdk release.
# This is the reference oracle for pgasm (DESIGN.md section 16 and 17.1).
#
# Idempotent: re-running skips the clone and rebuilds only if needed.
# Caches live under ~/.cache/polyglot/ only. Nothing is written into the repo.
# Prints the absolute path of the built pioasm binary on stdout (last line).

set -euo pipefail

# Pinned release. SDK 2.3.1 is the latest stable tag (not -rc or -correct-picotool)
# as of 2026-11-20, from `git ls-remote --tags https://github.com/raspberrypi/pico-sdk.git`.
PICO_SDK_TAG="2.3.1"
PICO_SDK_COMMIT="079c6f39023649b154152db30f1d781e884879bc"
PICO_SDK_URL="https://github.com/raspberrypi/pico-sdk.git"

CACHE_DIR="${HOME}/.cache/polyglot"
SDK_DIR="${CACHE_DIR}/pico-sdk"
BUILD_DIR="${CACHE_DIR}/pioasm-build"
PIOASM_BIN="${BUILD_DIR}/pioasm"

mkdir -p "${CACHE_DIR}"

# 1. Shallow clone at the pinned tag (skip if already present at the right commit).
if [ -d "${SDK_DIR}/.git" ] && [ "$(git -C "${SDK_DIR}" rev-parse HEAD)" = "${PICO_SDK_COMMIT}" ]; then
    echo "pico-sdk ${PICO_SDK_TAG} already cloned at ${SDK_DIR}" >&2
else
    rm -rf "${SDK_DIR}"
    git clone --depth 1 --branch "${PICO_SDK_TAG}" "${PICO_SDK_URL}" "${SDK_DIR}" >&2
    got="$(git -C "${SDK_DIR}" rev-parse HEAD)"
    if [ "${got}" != "${PICO_SDK_COMMIT}" ]; then
        echo "error: tag ${PICO_SDK_TAG} resolves to ${got}, expected ${PICO_SDK_COMMIT}" >&2
        exit 1
    fi
fi

# 2. Configure and build the standalone tools/pioasm (needs cmake, a C++11 compiler).
#    The parser/lexer are pre-generated in tools/pioasm/gen, so bison/flex are not needed.
#    PIOASM_VERSION_STRING is mandatory; the SDK's own Findpioasm.cmake passes the SDK version.
if [ ! -x "${PIOASM_BIN}" ] || [ "${SDK_DIR}/tools/pioasm/CMakeLists.txt" -nt "${PIOASM_BIN}" ]; then
    cmake -S "${SDK_DIR}/tools/pioasm" -B "${BUILD_DIR}" \
        -DCMAKE_BUILD_TYPE=Release \
        -DPIOASM_VERSION_STRING="${PICO_SDK_TAG}" \
        -DPIOASM_FLAT_INSTALL=1 >&2
    cmake --build "${BUILD_DIR}" --parallel >&2
fi

if [ ! -x "${PIOASM_BIN}" ]; then
    echo "error: build did not produce ${PIOASM_BIN}" >&2
    exit 1
fi

echo "${PIOASM_BIN}"
