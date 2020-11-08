module troubadour.gui.main_gui;

import std.path, std.string;
import std.conv: to;
import std.format;
import atelier;
import troubadour.player, troubadour.midi;
import troubadour.startup;

private {
    shared bool[16] _channelsChange;
    shared int[16] _channelsValue;
}

void registerChannelValue(int chan, int value) {
    if(chan < 0 || chan >= 16)
        return;
    _channelsChange[chan] = true;
    _channelsValue[chan] = value;
}

void resetChannelsValue() {
    for(int i; i < 16; ++ i) {
        _channelsChange[i] = true;
        _channelsValue[i] = -1;
    }
}

final class MainGui: GuiElement {
    private {
        Checkbox[16] _checkboxes;
        Checkbox _sendCb;

        Label[16] _notes;
    }

    this() {
        position(Vec2f.zero);
        size(screenSize);
        setAlign(GuiAlignX.left, GuiAlignY.top);

        {
            auto vbox = new VContainer;
            vbox.setAlign(GuiAlignX.left, GuiAlignY.center);
            vbox.position = Vec2f(50f, 0f);
            vbox.spacing = Vec2f(0f, 15f);
            vbox.setChildAlign(GuiAlignX.left);
            for(int i; i < 16; ++ i) {
                auto hbox = new HContainer;
                auto cb = new Checkbox;
                //cb.padding = Vec2f(25f, 25f);
                _checkboxes[i] = cb;
                cb.setCallback(this, "cb");
                hbox.addChildGui(cb);
                hbox.addChildGui(new Label(" - Canal " ~ to!string(i + 1) ~ " :   "));

                auto noteLabel = new Label("--");
                hbox.addChildGui(noteLabel);
                _notes[i] = noteLabel;
                _channelsValue[i] = -1;
                
                vbox.addChildGui(hbox);
            }
            addChildGui(vbox);
        }

        {
            auto vbox = new VContainer;
            vbox.setAlign(GuiAlignX.right, GuiAlignY.center);
            vbox.position = Vec2f(50f, 0f);
            vbox.spacing = Vec2f(0f, 10f);
            vbox.setChildAlign(GuiAlignX.left);
            {
                auto hbox = new HContainer;
                _sendCb = new Checkbox;
                _sendCb.setCallback(this, "send");
                hbox.addChildGui(_sendCb);
                hbox.addChildGui(new Label(" Send Input"));
                vbox.addChildGui(hbox);
            }
            {
                auto btn = new TextButton("Stop");
                btn.size = Vec2f(150f, 50f);
                btn.setCallback(this, "stop");
                vbox.addChildGui(btn);
            }
            {
                auto btn = new TextButton("Restart");
                btn.size = Vec2f(150f, 50f);
                btn.setCallback(this, "restart");
                vbox.addChildGui(btn);
            }
            addChildGui(vbox);
        }
    }

    override void onCallback(string id) {
        switch(id) {
        case "cb":
            for(int i; i < 16; ++ i) {
                setChannelActive(i, _checkboxes[i].value);
            }
            break;
        case "send":
            setSendInput(_sendCb.value);
            break;
        case "stop":
            stopMidi();
            break;
        case "restart":
            restartMidi();
            break;
        default:
            break;
        }
    }

    override void update(float deltaTime) {
        for(int i; i < 16; ++ i) {
            if(_channelsChange[i]) {
                int value = _channelsValue[i];
                if(value < 0) {
                    _notes[i].text = "--";
                }
                else {
                    _notes[i].text = format("%X", value);
                }
            }
        }
    }

    override void onEvent(Event event) {
        super.onEvent(event);

		switch(event.type) with(EventType) {
        case dropFile:
            const string ext = extension(event.drop.filePath).toLower;
            if(ext == ".mid" || ext == ".midi")
                playMidi(event.drop.filePath);
            break;
        case resize:
            size = cast(Vec2f) event.window.size;
            break;
        default:
            break;
        }
    }
}