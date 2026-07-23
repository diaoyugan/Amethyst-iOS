package org.lwjgl.glfw;

import java.util.*;
import net.kdt.pojavlaunch.Tools;

public class GLFWWindowProperties {
    public int width, height;
    public float x, y;
    public CharSequence title;
    public boolean shouldClose, isInitialSizeCalled, isCursorEntered;
    public long monitor;
    public Map<Integer, Integer> inputModes = new HashMap<>();
    public Map<Integer, Integer> windowAttribs = new HashMap<>();

    public int getInputMode(int mode) {
        Integer value = inputModes.get(mode);
        if (value != null) {
            return value;
        }

        // GLFW initializes the cursor to normal and all boolean input modes to false.
        // In particular, Minecraft 26.2 queries GLFW_IME before ever setting it.
        return mode == GLFW.GLFW_CURSOR ? GLFW.GLFW_CURSOR_NORMAL : GLFW.GLFW_FALSE;
    }
    
    @Override
    public String toString() {
        return "width=" + width + ", " +
          "height=" + height + ", " +
          "x=" + x + ", " +
          "y=" + y + ", ";
    }
}
