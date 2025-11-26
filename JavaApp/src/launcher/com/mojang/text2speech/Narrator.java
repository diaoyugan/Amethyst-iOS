package com.mojang.text2speech;

public interface Narrator {
    void say(String msg);
    void say(String msg, boolean interrupt);
    void say(String msg, boolean interrupt, float volume);

    void clear();

    boolean active();

    void destroy();

    static Narrator getNarrator() {
        return new NarratorOSX();
    }

    static void setJNAPath(String sep) {
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + "./src/natives/resources/");
        System.setProperty("jna.library.path", System.getProperty("jna.library.path") + sep + System.getProperty("java.library.path"));
    }
}
