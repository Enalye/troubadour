module troubadour.player;

import core.sys.windows.winuser;
import std.stdio;
import core.thread;
import std.file;
import minuit;
import atelier;
import troubadour.midi, troubadour.gui;

private {
    shared bool[16] _isChannelActive;
    PlayerSequencer _playerSequencer;
    string _currentFilePath;
    shared bool _sendInput;
}

void setupPlayer() {
    _playerSequencer = new PlayerSequencer;
    _playerSequencer.start();
}

void stopPlayer() {
	if(_playerSequencer)
		_playerSequencer.isRunning = false;
}

void playMidi(string filePath) {
    stopMidi();
    if(exists(filePath)) {
        _currentFilePath = filePath;
        MidiFile file = new MidiFile(filePath);
        setupMidiOutSequencer(file);
        startMidiOutSequencer();
    }
	startMidiClock();
}

void stopMidi() {
	stopMidiClock();
	stopMidiOutSequencer();
    resetChannelsValue();
}

void restartMidi() {
    if(_currentFilePath.length)
        playMidi(_currentFilePath);
}

void setChannelActive(int id, bool active) {
    if(id >= 0 && id < 16)
        _isChannelActive[id] = active;
}

bool getChannelActive(int id) {
    if(id >= 0 && id < 16)
        return _isChannelActive[id];
    return false;
}

void setSendInput(bool canSend) {
    _sendInput = canSend;
}

private final class PlayerSequencer: Thread {
	shared bool isRunning;

    private {
        int lastNote;
        bool isNotePlaying;
        MnInputHandle _midiInputHandle;
    }

    this() {
		super(&run);
    }

    void initProcess() {
        writeln("Liste des entrées midi:");
        int i;
        MnInputPort[] devices = mnFetchInputs();
        int id;
        if(devices.length > 1) {
            foreach(device; devices) {
                writeln(i, ": ", device.name);
                i ++;
            }
            write("> ");
            readf("%d", &id);
        }
        else if(devices.length > 0) {
            _midiInputHandle = mnOpenInput(devices[id]);
            writeln("Le serveur est en écoute sur ", devices[id].name);
        }
        else {
            _midiInputHandle = null;
            writeln("Aucune entrée midi détectée");
        }

        midiBuffer = new RingBuffer!(MidiEvent);
        initMidiClock();
    }

    private void run() {
        try {
			isRunning = true;
            initProcess();
            while(isRunning) {
                processMidi();

                Thread.sleep(dur!("msecs")(1));
            }
        }
        catch(Exception e) {
            import std.stdio: writeln;
            writeln(e.msg);
        }
    }

    void processMidi() {
        if(_midiInputHandle) {
            if(mnCanReceiveInput(_midiInputHandle) && _sendInput) {
                ubyte[] msg = mnReceiveInput(_midiInputHandle);
                if(msg.length) {
                    switch(msg[0]) {
                    case 144:
                        noteOn(msg[1]);
                        break;
                    case 128:
                        noteOff(msg[1]);
                        break;
                    default:
                        break;
                    }
                }
            }
        }
        while(!midiBuffer.isEmpty) {
            MidiEvent ev = midiBuffer.read();
            if(!_sendInput)
                continue;
            if(!getChannelActive(ev.note.channel))
                continue;
            switch(ev.type) with(MidiEventType) {
            case NoteOn:
                writeln("Note on: ", ev.note.note);
                noteOn(ev.note.note);
                break;
            case NoteOff:
                writeln("Note off: ", ev.note.note);
                noteOff(ev.note.note);
                break;
            default:
                break;
            }
        }
    }

    void noteOn(int midiKey) {
        if(isNotePlaying) {
            releaseKey(translateKey(lastNote));
        }
        while(midiKey > 84) {
            midiKey -= 12;
        }
        while(midiKey < 48) {
            midiKey += 12;
        }
        lastNote = midiKey;
        isNotePlaying = true;
        pressKey(translateKey(midiKey));
        Thread.sleep(dur!("msecs")(40));
    }

    void noteOff(int midiKey) {
        if(!isNotePlaying)
            return;
        while(midiKey > 84) {
            midiKey -= 12;
        }
        while(midiKey < 48) {
            midiKey += 12;
        }
        if(lastNote != midiKey)
            return;
        releaseKey(translateKey(lastNote));
        isNotePlaying = false;
    }

    int translateKey(int midiKey) {
        if(midiKey >= 48 && midiKey <= 73) {
            return 0x41 + (midiKey - 48);
        }
        if(midiKey >= 74 && midiKey <= 83) {
            return 0x30 + (midiKey - 74);
        }
        if(midiKey == 84) {
            return 0xBC;
        }
        /*if(midiKey == 29) {
            return 0xBB;
        }
        if(midiKey == 28) {
            return 0xBE;
        }*/
        return 0x0;
    }

    void pressKey(int key) {
        if(key <= 0)
            return;
        INPUT input;
        input.type = INPUT_KEYBOARD;
        input.ki.wScan = 0;
        input.ki.time = 0;
        input.ki.dwExtraInfo = 0;
        input.ki.wVk = cast(ushort) key;
        input.ki.dwFlags = 0;
        SendInput(1, &input, INPUT.sizeof);
    }

    void releaseKey(int key) {
        if(key <= 0)
            return;
        INPUT input;
        input.type = INPUT_KEYBOARD;
        input.ki.wScan = 0;
        input.ki.time = 0;
        input.ki.dwExtraInfo = 0;
        input.ki.wVk = cast(ushort) key;
        input.ki.dwFlags = KEYEVENTF_KEYUP;
        SendInput(1, &input, input.sizeof);
    }
}