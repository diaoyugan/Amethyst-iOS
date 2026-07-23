#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
    echo "Usage: $0 <minecraft-version> <full-ipa> <slimmed-ipa> <expected-commit>" >&2
    exit 2
fi

minecraft_version=$1
full_ipa=$2
slimmed_ipa=$3
expected_commit=$4
script_dir=$(cd "$(dirname "$0")" && pwd)
audit_root=$(mktemp -d)
trap 'rm -rf "$audit_root"' EXIT

for ipa in "$full_ipa" "$slimmed_ipa"; do
    test -f "$ipa"
    unzip -tq "$ipa" >/dev/null
done

extract_audit_files() {
    local ipa=$1
    local destination=$2
    mkdir -p "$destination"
    unzip -q "$ipa" \
        'Payload/*.app/AngelAuraAmethyst' \
        'Payload/*.app/libs/launcher.jar' \
        'Payload/*.app/libs/lwjgl.jar' \
        'Payload/*.app/Frameworks/libMoltenVK.dylib' \
        'Payload/*.app/Frameworks/libshaderc.dylib' \
        'Payload/*.app/Frameworks/libmobileglues.dylib' \
        'Payload/*.app/Frameworks/liblwjgl.dylib' \
        -d "$destination"
}

extract_audit_files "$full_ipa" "$audit_root/full"
extract_audit_files "$slimmed_ipa" "$audit_root/slimmed"

full_app=$(find "$audit_root/full/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print -quit)
slimmed_app=$(find "$audit_root/slimmed/Payload" -mindepth 1 -maxdepth 1 -type d -name '*.app' -print -quit)
test -n "$full_app"
test -n "$slimmed_app"

critical_files=(
    AngelAuraAmethyst
    libs/launcher.jar
    libs/lwjgl.jar
    Frameworks/libMoltenVK.dylib
    Frameworks/libshaderc.dylib
    Frameworks/libmobileglues.dylib
    Frameworks/liblwjgl.dylib
)

for relative_path in "${critical_files[@]}"; do
    cmp "$full_app/$relative_path" "$slimmed_app/$relative_path"
done

native_files=(
    AngelAuraAmethyst
    Frameworks/libMoltenVK.dylib
    Frameworks/libshaderc.dylib
    Frameworks/libmobileglues.dylib
    Frameworks/liblwjgl.dylib
)

for relative_path in "${native_files[@]}"; do
    native_file="$full_app/$relative_path"
    lipo -verify_arch arm64 "$native_file"
    test "$(lipo -archs "$native_file")" = "arm64"
done

strings -a "$full_app/AngelAuraAmethyst" | grep -Fxq "$expected_commit"

"$JAVA_HOME/bin/javap" -classpath "$full_app/libs/lwjgl.jar" -constants org.lwjgl.glfw.GLFW \
    | grep -q 'GLFW_IME = 208903'

mkdir -p "$audit_root/test-classes"
"$JAVA_HOME/bin/javac" \
    -classpath "$full_app/libs/lwjgl.jar" \
    -d "$audit_root/test-classes" \
    "$script_dir/tests/org/lwjgl/glfw/GLFWWindowPropertiesTest.java"
"$JAVA_HOME/bin/java" \
    -classpath "$full_app/libs/lwjgl.jar:$audit_root/test-classes" \
    org.lwjgl.glfw.GLFWWindowPropertiesTest

manifest_json="$audit_root/version_manifest.json"
version_json="$audit_root/$minecraft_version.json"
client_jar="$audit_root/minecraft-$minecraft_version-client.jar"

curl --fail --location --retry 4 --retry-all-errors \
    'https://piston-meta.mojang.com/mc/game/version_manifest_v2.json' \
    --output "$manifest_json"

version_url=$(
    python3 -c \
        'import json,sys; data=json.load(open(sys.argv[1], encoding="utf-8")); print(next(v["url"] for v in data["versions"] if v["id"] == sys.argv[2]))' \
        "$manifest_json" "$minecraft_version"
)
curl --fail --location --retry 4 --retry-all-errors "$version_url" --output "$version_json"

client_url=$(
    python3 -c \
        'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["downloads"]["client"]["url"])' \
        "$version_json"
)
client_sha1=$(
    python3 -c \
        'import json,sys; print(json.load(open(sys.argv[1], encoding="utf-8"))["downloads"]["client"]["sha1"])' \
        "$version_json"
)
curl --fail --location --retry 4 --retry-all-errors "$client_url" --output "$client_jar"
echo "$client_sha1  $client_jar" | shasum -a 1 -c -

python3 "$script_dir/verify-java-linkage.py" \
    --consumer "$client_jar" \
    --provider "$full_app/libs/lwjgl.jar" \
    --prefix 'org/lwjgl/'

echo "Critical packaged files are identical in both IPA variants:"
for relative_path in "${critical_files[@]}"; do
    shasum -a 256 "$full_app/$relative_path"
done
