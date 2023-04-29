

MIDIdef.noteOn(\on, { |val, num| ~grain.set(\rate, (num-40).midiratio); ~out.set(\note, num) });

MIDIdef.noteOff(\off, { |val, num| ~grain.set(\rate, 1); ~out.set(\note, 0) });

MIDIdef.bend(\bend, { |val| var bend = val.linlin(0,2**14-1, -2.0,2.0); ~grain.set(\bend, bend); ~out.set(\bend, bend) })

	

