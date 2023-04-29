
SynthDef(\rec, { |i_buf=#[0,1], feedback=0.0|
	
	var bufdur,env,sIn,trig;
	bufdur = BufDur.kr(i_buf[0]);
	trig = DigitalIn.kr(1);
	//trig = 1;
	env = Linen.kr(trig, 0.01, 1, 0.01);
	sIn = SoundIn.ar([0,1], 1) * env;
	
	RecordBuf.ar(sIn[0], i_buf[0], recLevel: 1-(feedback*0.8), preLevel: feedback*1.0, trigger:0, run:env, loop:1);
	RecordBuf.ar(sIn[1], i_buf[1], recLevel: 1-(feedback*0.8), preLevel: feedback*1.0, trigger:0, run:env, loop:1);
	0.0
	
}).send(s);

SynthDef(\playback, {|i_buf=#[0,1], out| Out.ar(~playBus.index, Linen.kr(1,doneAction: 2) * PlayBuf.ar(1, i_buf, loop: 1) * 2) }).send(s);

SynthDef(\grain, { |i_buf=#[0,1], args=#[0.0,0.0,0.02,0.1,0.01], envbuf=(-1), bend=0, rate=1, latch=1, out|
	
	// args: disp, bufpos, dur, dens, prtmt
	var sig, trig, disp, dens, dur;
	var env = Linen.kr(DigitalIn.kr(1) + latch, 0.01, 1, 0.1);
	//var env = Linen.kr(1, 0.01, 1, 0.1);
	
	dens = args[3] * 15 + 1;
	dur = args[2] * 1.9 + 0.1;
	
	trig = Dust.kr(dens!2);
	disp = TRand.kr(0.0, 1.0, trig) * args[0];
	
	sig = GrainBuf.ar(
		numChannels: 1,
		trigger: trig,
		dur: (dens.reciprocal).sqrt * dur,
		sndbuf: i_buf,
		rate: rate.lag(args[4]) * disp.range(-5.0,5.0).midiratio * bend.midiratio,
		pos: (disp + args[1] - dur).min(1-dur),
		envbufnum: envbuf,
		maxGrains: 32
	);
	
	Out.ar(~grainBus.index, sig * env * 1.7)
	
}).send(s);

SynthDef(\fx, {|args=#[0.01,1.0,1.0,0.0,1.0,0.1,1], fl=#[0.3,0.2,0.5], note=0, bend=0, out|
	
	// args: prtmnt, mix, ffreq, rq, wet, master, preGain
	// fl args: fl_rate, fl_delay, fl_depth
	var in, sig, local;
	var maxdelay = 0.013;
	var delaytime = LFPar.kr(fl[0].linexp(0.0,1.0,0.1,10), { rrand(0,4.0) }!2).range(fl[1], 1-fl[1] * fl[2]) + 0.01 * maxdelay;
	var freq = ((note + 60).midicps * args[2].linlin(0.0,1.0,-12,12).midiratio * bend.midiratio).clip2(14000);
	
	//[args[1], args[4]].poll(0.5);
	in = SelectX.ar(args[1].round(0.01), [~playBus.ar, ~grainBus.ar]);
	sig = RLPF.ar(in, freq.lag(args[0]), args[3].linlin(0.0,1.0,1.0,0.03));
	sig = (sig * (args[6] + 0.15 * 4)).tanh;

	local = LocalIn.ar(2);
	local = AllpassC.ar(
		in: local * 0.003 + sig,
		maxdelaytime: maxdelay * 2,
		delaytime: delaytime,
		decaytime: 0.015,
		add: sig
	);
	
	LocalOut.ar(local);
	
	sig = SelectX.ar(args[4].round(0.01), [in * 2, local]);
	sig = sig * args[5];
	
	sig = HPF.ar(LPF.ar(BRF.ar(sig, 780, 0.99), 17000), 100);
	
	Out.ar(out, sig);
	
}).send(s);

