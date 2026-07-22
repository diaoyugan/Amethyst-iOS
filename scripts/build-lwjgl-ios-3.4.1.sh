#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "usage: $0 <amethyst-root> <overlay-output>" >&2
    exit 2
fi

AMETHYST_ROOT=$(cd "$1" && pwd)
OVERLAY_OUTPUT=$2
LWJGL_VERSION=3.4.1
LWJGL_REVISION=b800ccffab14396fc529ddb6c931b7c5c5226763
LIBFFI_VERSION=3.4.8
LWJGL_SOURCE="${RUNNER_TEMP:-/tmp}/amethyst-lwjgl-${LWJGL_VERSION}"
LIBFFI_SOURCE="${RUNNER_TEMP:-/tmp}/amethyst-libffi-${LIBFFI_VERSION}"
LIBFFI_BUILD="$LIBFFI_SOURCE/build_iphoneos-arm64"
LIBFFI_ARCHIVE="$LIBFFI_BUILD/.libs/libffi.a"

if [[ -z "$OVERLAY_OUTPUT" || "$OVERLAY_OUTPUT" == "/" || "$OVERLAY_OUTPUT" == "$AMETHYST_ROOT" ]]; then
    echo "refusing unsafe overlay output path: $OVERLAY_OUTPUT" >&2
    exit 2
fi

rm -rf "$LWJGL_SOURCE" "$LIBFFI_SOURCE" "$OVERLAY_OUTPUT"
git init "$LWJGL_SOURCE"
git -C "$LWJGL_SOURCE" remote add origin https://github.com/LWJGL/lwjgl3.git
git -C "$LWJGL_SOURCE" fetch --depth 1 origin \
    "refs/tags/${LWJGL_VERSION}:refs/tags/${LWJGL_VERSION}"
FETCHED_LWJGL_REVISION=$(git -C "$LWJGL_SOURCE" rev-parse "${LWJGL_VERSION}^{}")
if [[ "$FETCHED_LWJGL_REVISION" != "$LWJGL_REVISION" ]]; then
    echo "LWJGL tag ${LWJGL_VERSION} resolved to unexpected commit ${FETCHED_LWJGL_REVISION}" >&2
    exit 1
fi
git -C "$LWJGL_SOURCE" checkout --detach "$LWJGL_REVISION"
git -C "$LWJGL_SOURCE" apply --recount "$AMETHYST_ROOT/scripts/lwjgl-ios-3.4.1.patch"

# Populate the Java build toolchain while network access is enabled. Native
# dependencies are seeded below with iOS builds, then native downloads are disabled.
ant -f "$LWJGL_SOURCE/update-dependencies.xml" update-dependencies

curl --fail --location --retry 3 \
    "https://github.com/libffi/libffi/releases/download/v${LIBFFI_VERSION}/libffi-${LIBFFI_VERSION}.tar.gz" \
    --output "${LIBFFI_SOURCE}.tar.gz"
mkdir -p "$LIBFFI_SOURCE"
tar -xzf "${LIBFFI_SOURCE}.tar.gz" --strip-components=1 -C "$LIBFFI_SOURCE"
(
    cd "$LIBFFI_SOURCE"
    # libffi's --only-ios still generates obsolete i386/armv7 targets.
    # Xcode 16 no longer ships an i386 simulator toolchain, so generate only
    # the arm64 device headers and archive required by this iOS build.
    sed -i.bak -E \
        '/build_target\(ios_/ { /ios_device_arm64_platform/! s/^([[:space:]]*)/\1#/; }' \
        generate-darwin-source-and-headers.py
    python3 generate-darwin-source-and-headers.py --only-ios
    # Reconfigure the generated arm64 directory so libtool records the complete
    # iOS target triple. Its default unversioned target plus bitcode flags emit
    # macOS-tagged objects on current Apple Silicon runners.
    IOS_SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
    make -C "$LIBFFI_BUILD" distclean
    (
        cd "$LIBFFI_BUILD"
        env \
            CC="xcrun -sdk iphoneos clang -target arm64-apple-ios14.0" \
            LD="xcrun -sdk iphoneos ld" \
            CFLAGS="-Wall -isysroot $IOS_SDKROOT -miphoneos-version-min=14.0 -fexceptions" \
            ../configure --host=arm64-apple-ios --build="$(uname -m)-apple-darwin" \
                --disable-shared --enable-static
        make -j"$(sysctl -n hw.logicalcpu)"
    )
    xcrun lipo "$LIBFFI_ARCHIVE" -verify_arch arm64
    mkdir -p verify-ios-object
    (
        cd verify-ios-object
        xcrun ar -x "$LIBFFI_ARCHIVE" prep_cif.o
        xcrun vtool -show-build prep_cif.o | grep -q 'platform IOS'
    )
)

LWJGL_NATIVE="$LWJGL_SOURCE/bin/libs/native/macos/arm64/org/lwjgl"
mkdir -p \
    "$LWJGL_NATIVE/freetype" \
    "$LWJGL_NATIVE/openal" \
    "$LWJGL_NATIVE/shaderc" \
    "$LWJGL_NATIVE/spvc" \
    "$LWJGL_NATIVE/vulkan"
cp "$LIBFFI_ARCHIVE" "$LWJGL_NATIVE/libffi.a"
cp "$AMETHYST_ROOT/Natives/resources/Frameworks/libfreetype.dylib" "$LWJGL_NATIVE/freetype/libfreetype.dylib"
cp "$AMETHYST_ROOT/Natives/resources/Frameworks/libopenal.dylib" "$LWJGL_NATIVE/openal/libopenal.dylib"
cp "$AMETHYST_ROOT/Natives/resources/Frameworks/libshaderc.dylib" "$LWJGL_NATIVE/shaderc/libshaderc.dylib"
cp "$AMETHYST_ROOT/Natives/external/MobileGlues/src/main/cpp/libraries/ios/libspirv-cross-c-shared.0.dylib" \
    "$LWJGL_NATIVE/spvc/libspirv-cross.dylib"
touch "$LWJGL_SOURCE/bin/libs/native/macos/arm64/touch.txt"

export LWJGL_BUILD_ARCH=arm64
export LWJGL_BUILD_OFFLINE=1
(
    cd "$LWJGL_SOURCE"
    ant -Dplatform.macos=true \
        -Dbinding.assimp=false -Dbinding.bgfx=false -Dbinding.cuda=false \
        -Dbinding.egl=false -Dbinding.fmod=false -Dbinding.harfbuzz=false \
        -Dbinding.hwloc=false -Dbinding.jawt=false -Dbinding.jemalloc=false -Dbinding.ktx=false \
        -Dbinding.libdivide=false -Dbinding.llvm=false -Dbinding.lmdb=false \
        -Dbinding.lz4=false -Dbinding.meow=false -Dbinding.meshoptimizer=false \
        -Dbinding.msdfgen=false -Dbinding.nanovg=false -Dbinding.nfd=false \
        -Dbinding.nuklear=false -Dbinding.odbc=false -Dbinding.opencl=false \
        -Dbinding.opengles=false -Dbinding.openvr=false -Dbinding.openxr=false \
        -Dbinding.opus=false -Dbinding.par=false -Dbinding.remotery=false \
        -Dbinding.renderdoc=false -Dbinding.rpmalloc=false -Dbinding.sdl=false -Dbinding.spng=false \
        -Dbinding.sse=false -Dbinding.tinyexr=false -Dbinding.tootle=false \
        -Dbinding.xxhash=false -Dbinding.yoga=false -Dbinding.zstd=false \
        -Djavadoc.skip=true compile-templates compile-native
)

FRAMEWORKS="$OVERLAY_OUTPUT/Natives/resources/Frameworks"
JARS="$OVERLAY_OUTPUT/JavaApp/libs/lwjgl"
mkdir -p "$FRAMEWORKS" "$JARS"
find "$LWJGL_NATIVE" -name 'liblwjgl*.dylib' -exec cp {} "$FRAMEWORKS" \;

MODULES=(lwjgl lwjgl-freetype lwjgl-glfw lwjgl-jemalloc lwjgl-openal lwjgl-opengl lwjgl-shaderc lwjgl-spvc lwjgl-stb lwjgl-tinyfd lwjgl-vma lwjgl-vulkan)
for module in "${MODULES[@]}"; do
    curl --fail --location --retry 3 \
        "https://repo1.maven.org/maven2/org/lwjgl/${module}/${LWJGL_VERSION}/${module}-${LWJGL_VERSION}.jar" \
        --output "$JARS/${module}.jar"
done

# Verify that every produced native is an arm64 iOS Mach-O before publishing it.
while IFS= read -r dylib; do
    file "$dylib" | grep -q 'arm64'
    xcrun vtool -show-build "$dylib" | grep -q 'platform IOS'
done < <(find "$FRAMEWORKS" -name '*.dylib' -print)

echo "LWJGL ${LWJGL_VERSION} iOS overlay created at $OVERLAY_OUTPUT"
