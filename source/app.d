import minuit;
import std.stdio;
import core.thread;
import core.sys.windows.winuser;
import std.file;

import sequencer, ringbuffer, file, clock;

private {
	bool _isRunning = true;
}

void main(string[] args) {
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
	MnInputHandle input = mnOpenInput(devices[id]);
	writeln("Le serveur est en écoute sur ", devices[id].name);

	midiBuffer = new RingBuffer!(MidiEvent);
	initMidiClock();
	if(args.length > 1) {
		if(exists(args[1])) {
			MidiFile file = new MidiFile(args[1]);
			setupMidiOutSequencer(file);
			startMidiOutSequencer();
		}
	}
	startMidiClock();
	while(_isRunning) {
		/*
			TODO:
				Remplacer le if par while, et trier les événements arrivant en même temps par hauteur de note

		*/
		if(mnCanReceiveInput(input)) {
			ubyte[] msg = mnReceiveInput(input);
			if(msg.length) {
				// TODO: exclure les vélocités trop faibles
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
		while(!midiBuffer.isEmpty) {
			MidiEvent ev = midiBuffer.read();
			switch(ev.type) with(MidiEventType) {
			case NoteOn:
				writeln("Note on: ", ev.note.note);
				noteOn(ev.note.note);
				break;
			case NoteOff:
				writeln("Note off: ", ev.note.note);
				noteOn(ev.note.note);
				break;
			default:
				break;
			}
		}
		//A mimir
        Thread.sleep(dur!("msecs")(1));
	}
	stopMidiClock();
	stopMidiOutSequencer();
}

/// Capture interruptions.
extern(C) void signalHandler(int sig) nothrow @nogc @system {
	cast(void) sig;
	_isRunning = false;
}

int lastNote;
bool isNotePlaying;

void noteOn(int midiKey) {
	if(isNotePlaying) {
		releaseKey(translateKey(lastNote));
	}
	lastNote = midiKey;
	isNotePlaying = true;
	pressKey(translateKey(midiKey));
	Thread.sleep(dur!("msecs")(40));
}

void noteOff(int midiKey) {
	if(!isNotePlaying)
		return;
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
	if(midiKey == 29) {
		return 0xBB;
	}
	if(midiKey == 28) {
		return 0xBE;
	}
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