# Minecraft 26.2+ MoltenVK support

Minecraft 26.2 introduced an experimental Vulkan graphics backend. On Amethyst,
the backend uses the existing Metal surface bridge and MoltenVK.

## Using it

1. Edit a game profile whose resolved Minecraft version is 26.2 or newer.
2. Set **Graphics API (Minecraft 26.2+)** to **MoltenVK (Vulkan)**.
3. Keep **Renderer** configured as the desired OpenGL fallback.

At launch, Amethyst writes `preferredGraphicsBackend:vulkan` to that instance's
`options.txt`. The profile setting is ignored for older Minecraft versions. **Use
game setting** leaves the existing option unchanged; **Minecraft default** explicitly
restores Minecraft's automatic backend choice.

## Building from Windows

Run the **Minecraft 26.2 MoltenVK dependencies** workflow manually in GitHub Actions.
It builds and validates:

- LWJGL 3.4.1 arm64 iOS native libraries;
- MoltenVK 1.4.1 for iOS;
- the matching LWJGL Java modules, including shaderc, SPIRV-Cross and VMA;
- a test IPA on a public GitHub-hosted macOS runner.

The workflow publishes both a dependency overlay and the test IPA. The overlay keeps
the platform-specific binaries reproducible instead of requiring an iOS toolchain on
Windows.

## Current limitation

Minecraft 26.2's new GLFW preedit and IME-status callback signatures are accepted,
but native iOS preedit registration is currently a no-op. Normal key and character
callbacks continue to use Amethyst's existing input bridge.
