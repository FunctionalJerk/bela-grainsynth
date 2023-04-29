s.sync;

~map = {|test0=3,test1=0,test2=13, bus0=15,bus1=16,bus2=17|
	
	var vals, tests, sel, diff;
	
	vals = AnalogIn.kr([2,3,5]) * 1.206;
	tests = [test0,test1,test2];
	
	sel = Select.kr(tests, ~vars.kr);
	diff = (vals - sel).abs;
	
	ReplaceOut.kr(bus0 + ~vars.index, vals[0]);
	ReplaceOut.kr(bus1 + ~vars.index, vals[1]);
	ReplaceOut.kr(bus2 + ~vars.index, vals[2]);
	
	SendReply.kr((diff < 0.02) ++ Changed.kr(tests), cmdName: '/faders', values: tests ++ tests, replyID: (0..5));
	0.0
}.play;

OSCdef(\map, { |msg|
	
	var replies = msg[3..].asInteger;
	var faderNr = msg[2];
	var busNr = replies[faderNr];
	
	switch(faderNr,
		0, { ~map.set(\bus0, busNr); [faderNr, busNr].postln },
		1, { ~map.set(\bus1, busNr); [faderNr, busNr].postln },
		2, { ~map.set(\bus2, busNr);/*; [faderNr, busNr].postln */ },
		
		// Abstellgleis
		3, { ~map.set(\bus0, 15) },
		4, { ~map.set(\bus1, 16) },
		5, { ~map.set(\bus2, 17) }
	)
}, '/faders', s.addr);

~preset.(0,1);

// rotary-encoder
{
	var dig,ins,change;

	dig = DigitalIn.kr([0,2,4]);
	ins = [ (HPZ1.kr(dig[2] * dig[1]) > 0) * Delay1.kr(dig[2] - dig[1]), (1 - dig[0]) > 0 ];
	change = [ Trig1.kr(Changed.kr(ins[0] , 0), 0.1), ins[1] ]; // digital enc [ +1/-1, click ]

	SendReply.kr(change, '/dial', ins, [0,1]);
	0.0
}.play(s);

// Synths
~rec = Synth(\rec, [\i_buf, ~recBuf]);
~rec.map(\feedback, ~vars.subBus(14,1));

~play = Synth.after(~rec, \playback, [\i_buf, ~recBuf]);

~grain = Synth.after(~play, \grain, [\i_buf, ~recBuf, \envbuf, ~envs[~truths[4]]]);
~grain.map(\args, ~vars.subBus(0,5));

~out = Synth.after(~grain, \fx);
~out.map(\args, ~vars.subBus(4,7), \fl, ~vars.subBus(11,3) );