package org.lwjgl.glfw;

public final class GLFWWindowPropertiesTest {
    public static void main(String[] args) {
        GLFWWindowProperties properties = new GLFWWindowProperties();

        assertEquals(GLFW.GLFW_CURSOR_NORMAL, properties.getInputMode(GLFW.GLFW_CURSOR));
        assertEquals(GLFW.GLFW_FALSE, properties.getInputMode(GLFW.GLFW_IME));
        assertEquals(GLFW.GLFW_FALSE, properties.getInputMode(GLFW.GLFW_UNLIMITED_MOUSE_BUTTONS));

        properties.inputModes.put(GLFW.GLFW_IME, GLFW.GLFW_TRUE);
        assertEquals(GLFW.GLFW_TRUE, properties.getInputMode(GLFW.GLFW_IME));
    }

    private static void assertEquals(int expected, int actual) {
        if (expected != actual) {
            throw new AssertionError("expected " + expected + ", got " + actual);
        }
    }
}
