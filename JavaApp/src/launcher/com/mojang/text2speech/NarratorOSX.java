package com.mojang.text2speech;

public class NarratorOSX implements Narrator {
    public NarratorOSX() {
    }

    @Override
    public void say(String msg) {
        say(msg, false);
    }

    @Override
    public void say(final String msg, final boolean interrupt) {
        say(msg, interrupt, 1.0f);
    }

    @Override
    public void say(final String msg, final boolean interrupt, float volume) {
        if (interrupt) {
            clear();
        }
        nativeStartSpeaking(msg, volume);
    }

    @Override
    public void clear() {
        nativeClearQueue();
    }

    @Override
    public boolean active() {
        return true;
    }
    
    @Override
    public void destroy() {

    }
    
    static {
        System.load(System.getenv("BUNDLE_PATH") + "/AngelAuraAmethyst");
    }

    private static native void nativeStartSpeaking(String msg, float volume);
    private static native void nativeClearQueue();
}
