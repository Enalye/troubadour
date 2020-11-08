module troubadour.midi.sequencer;

import std.stdio;
import std.file;
import std.algorithm;
import core.thread;

import atelier;
import troubadour.midi.file, troubadour.midi.clock;
import troubadour.gui;

__gshared RingBuffer!(MidiEvent) midiBuffer;

auto speedFactor = 1f;
auto initialBpm = 120;

struct TempoEvent {
	uint tick, usPerQuarter;
}

private MidiSequencer _midiSequencer;

void setupMidiOutSequencer(MidiFile midiFile) {
	_midiSequencer = new MidiSequencer(midiFile);
}

void startMidiOutSequencer() {
	if(_midiSequencer)
		_midiSequencer.start();
}

void stopMidiOutSequencer() {
	if(_midiSequencer) {
		_midiSequencer.isRunning = false;
        _midiSequencer = null;
        Thread.sleep(dur!("msecs")(100));
    }
}

private final class MidiSequencer: Thread {
	MidiEvent[] events;
	uint eventsTop;

	TempoEvent[] tempoEvents;
	uint tempoEventsTop;

	long ticksPerQuarter;
	long tickAtLastChange = -1000;
	double ticksElapsedSinceLastChange, tickPerMs, msPerTick, timeAtLastChange;

	shared bool isRunning;

	this(MidiFile midiFile) {
		speedFactor = 1f;
		initialBpm = 120;

		ticksPerQuarter = midiFile.ticksPerBeat;

		foreach(uint t; 0 .. cast(uint)midiFile.tracks.length) {
			foreach(MidiEvent event; midiFile.tracks[t]) {
				//Fill in the tempo track.
				if(event.subType == MidiEvents.Tempo) {
					//writeln("Tempo: ", event.type);
					TempoEvent tempoEvent;
					tempoEvent.tick = event.tick;
					tempoEvent.usPerQuarter = event.tempo.microsecondsPerBeat;
					tempoEvents ~= tempoEvent;
					continue;
				}

				if(event.type == 0xFF) {
					//if(event.text)
					//	writeln("Text: ", event.text);
					continue;
				}
				events ~= event;
			}
		}

		sort!(
			(a, b) => (a.tick == b.tick) ?
			(a.type != MidiEventType.NoteOn && b.type == MidiEventType.NoteOn) :
			(a.tick < b.tick)
			)(events);

		//Set initial time step (120 BPM).
		tickPerMs = (initialBpm * ticksPerQuarter * speedFactor) / 60_000f;
		msPerTick = 60_000f / (initialBpm * ticksPerQuarter * speedFactor);

		super(&run);
	}

	private void run() {
		try {
			//Set initial time step (120 BPM).
			tickAtLastChange = 0;
			tickPerMs = (initialBpm * ticksPerQuarter * speedFactor) / 60_000f;
			msPerTick = 60_000f / (initialBpm * ticksPerQuarter * speedFactor);
			timeAtLastChange = 0;

			isRunning = true;
			//writeln("tempo: ", tempoEvents.length, ", ", tempoEventsTop);

			while(isRunning) {
				//Time handling.
				double currentTime = getMidiTime();
				
				checkTempo:
				double msDeltaTime = currentTime - timeAtLastChange; //The time since last tempo change.
				ticksElapsedSinceLastChange = msDeltaTime * tickPerMs;

				double totalTicksElapsed = tickAtLastChange + ticksElapsedSinceLastChange;

				if(tempoEvents.length > tempoEventsTop) {
					long tickThreshold = tempoEvents[tempoEventsTop].tick;
					if(totalTicksElapsed > tickThreshold) {
						long tickDelta = tickThreshold - tickAtLastChange;
						double finalDeltaTime = tickDelta * msPerTick;

						long usPerQuarter = tempoEvents[tempoEventsTop].usPerQuarter;
						tempoEventsTop ++;

						ticksElapsedSinceLastChange = 0;
						tickAtLastChange = tickThreshold;
						timeAtLastChange += finalDeltaTime;
						tickPerMs = (1000f * ticksPerQuarter * speedFactor) / usPerQuarter;
						msPerTick = usPerQuarter / (ticksPerQuarter * 1000f * speedFactor);

						if(isRunning)
							goto checkTempo;
					}
				}
				
				//Events handling.
				checkTick: if(events.length > eventsTop) {
					uint tickThreshold = events[eventsTop].tick;
					if(totalTicksElapsed > tickThreshold) {
						MidiEvent ev = events[eventsTop];
                        sendEvent(ev);
						eventsTop ++;
						if(isRunning)
							goto checkTick;
					}
				}

                Thread.sleep(dur!("msecs")(1));
            }
        }
        catch(Exception e) {
            import std.stdio: writeln;
            writeln(e.msg);
        }
    }

    private void sendEvent(MidiEvent ev) {
        if(midiBuffer.isFull)
            midiBuffer.read();
        switch(ev.type) with(MidiEventType) {
            case NoteOn:
                registerChannelValue(ev.note.channel, ev.note.note);
                midiBuffer.write(ev);
                break;
            case NoteOff:
                registerChannelValue(ev.note.channel, -1);
                midiBuffer.write(ev);
                break;
            default:
                break;
        }
    }
}