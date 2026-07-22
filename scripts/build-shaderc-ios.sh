#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "usage: $0 <overlay-output>" >&2
    exit 2
fi

SHADERC_VERSION=v2026.1
SHADERC_REVISION=301b4ede53d59b68bf55f95bb26412d9233c8187
OVERLAY_OUTPUT=$1
SHADERC_SOURCE="${RUNNER_TEMP:-/tmp}/amethyst-shaderc-${SHADERC_VERSION}"
SHADERC_BUILD="${RUNNER_TEMP:-/tmp}/amethyst-shaderc-${SHADERC_VERSION}-build"

if [[ -z "$OVERLAY_OUTPUT" || "$OVERLAY_OUTPUT" == "/" ]]; then
    echo "refusing unsafe overlay output path: $OVERLAY_OUTPUT" >&2
    exit 2
fi
if [[ -e "$SHADERC_SOURCE" || -e "$SHADERC_BUILD" || -e "$OVERLAY_OUTPUT" ]]; then
    echo "refusing to overwrite an existing Shaderc build path" >&2
    exit 2
fi

git init "$SHADERC_SOURCE"
git -C "$SHADERC_SOURCE" remote add origin https://github.com/google/shaderc.git
git -C "$SHADERC_SOURCE" fetch --depth 1 origin \
    "refs/tags/${SHADERC_VERSION}:refs/tags/${SHADERC_VERSION}"
FETCHED_REVISION=$(git -C "$SHADERC_SOURCE" rev-parse "${SHADERC_VERSION}^{}")
if [[ "$FETCHED_REVISION" != "$SHADERC_REVISION" ]]; then
    echo "Shaderc tag ${SHADERC_VERSION} resolved to unexpected commit ${FETCHED_REVISION}" >&2
    exit 1
fi
git -C "$SHADERC_SOURCE" checkout --detach "$SHADERC_REVISION"

# Shaderc's DEPS file pins glslang, SPIRV-Headers and SPIRV-Tools revisions.
python3 "$SHADERC_SOURCE/utils/git-sync-deps"

IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
cmake -S "$SHADERC_SOURCE" -B "$SHADERC_BUILD" -G Ninja \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_SYSTEM_NAME=iOS \
    -DCMAKE_OSX_SYSROOT="$IOS_SDKROOT" \
    -DCMAKE_OSX_ARCHITECTURES=arm64 \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=14.0 \
    -DCMAKE_INSTALL_NAME_DIR=@rpath \
    -DSHADERC_SKIP_TESTS=ON \
    -DSHADERC_SKIP_EXAMPLES=ON \
    -DSHADERC_SKIP_EXECUTABLES=ON \
    -DSHADERC_SKIP_COPYRIGHT_CHECK=ON \
    -DSHADERC_SKIP_INSTALL=ON \
    -DSHADERC_ENABLE_WERROR_COMPILE=OFF \
    -DENABLE_GLSLANG_INSTALL=OFF \
    -DSPIRV_SKIP_TESTS=ON \
    -DSPIRV_SKIP_EXECUTABLES=ON
cmake --build "$SHADERC_BUILD" --target shaderc_shared \
    --parallel "$(sysctl -n hw.logicalcpu)"

SHADERC_BINARY=$(find "$SHADERC_BUILD" -type f -name 'libshaderc_shared*.dylib' -print -quit)
if [[ -z "$SHADERC_BINARY" ]]; then
    echo "Shaderc shared library was not produced" >&2
    exit 1
fi

FRAMEWORKS="$OVERLAY_OUTPUT/Natives/resources/Frameworks"
mkdir -p "$FRAMEWORKS"
cp "$SHADERC_BINARY" "$FRAMEWORKS/libshaderc.dylib"
install_name_tool -id @rpath/libshaderc.dylib "$FRAMEWORKS/libshaderc.dylib"

file "$FRAMEWORKS/libshaderc.dylib" | grep -q 'arm64'
xcrun vtool -show-build "$FRAMEWORKS/libshaderc.dylib" | grep -q 'platform IOS'
xcrun dyld_info -exports "$FRAMEWORKS/libshaderc.dylib" \
    | grep -q '_shaderc_compile_options_set_max_id_bound'

echo "Shaderc ${SHADERC_VERSION} iOS overlay created at $OVERLAY_OUTPUT"
