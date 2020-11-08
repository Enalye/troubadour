module troubadour.startup;

import minuit;
import std.stdio;
import core.thread;
import std.file;

import atelier;
import troubadour.loader, troubadour.midi, troubadour.gui, troubadour.player;

private {
    MainGui _mainGui;
}

void setupApplication(string[] args) {
    enableAudio(false);
    createApplication(Vec2u(1280u, 720u), "Troubadour");

    setWindowMinSize(Vec2u(500, 200));
    setWindowClearColor(Color.black);

    onStartupLoad(&onLoadComplete);

    scope(exit) {
        //We need to clean up the remaining threads.
        stopPlayer();
        stopMidiClock();
        stopMidiOutSequencer();
    }
    runApplication();
    destroyApplication();
}

private void onLoadComplete() {
    setDefaultFont(fetch!TrueTypeFont("Cascadia"));
    _mainGui = new MainGui;
    
    setupPlayer();
    onMainMenu();
}

private void onMainMenu() {
    removeRootGuis();
    addRootGui(_mainGui);
}