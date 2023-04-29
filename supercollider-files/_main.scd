
s = Server.default;

s.options.numAnalogInChannels = 8;
s.options.numAnalogOutChannels = 8;
s.options.numDigitalChannels = 8;

s.options.blockSize = 16;
s.options.numInputBusChannels = 2;
s.options.numOutputBusChannels = 2;
//s.options.belaMaxScopeChannels = 4;

~truths = [14,6,7,0,3,0];

~selector = 0;
~pointer = 0;
~mode = 0;

~displayOSC = NetAddr.new("127.0.0.1", 7562);
~displayOSC.sendMsg('/booting');

MIDIClient.init;
// indices are not consistent
// more devices can be added here 

~midi = MIDIClient.sources.collect{|x| x.name };
~virmidi = ~midi.indexOfEqual("Virtual RawMIDI");
~keys = ~midi.indexOfEqual("Arturia KeyStep 37 MIDI 1");

if( ~virmidi.notNil ) { MIDIIn.connect(~virmidi, MIDIClient.sources[~virmidi]) };
if( ~keys.notNil ) { MIDIIn.connect(~keys, MIDIClient.sources[~keys]) };

s.waitForBoot({

	var path = PathName(thisProcess.nowExecutingPath.dirname);
	var rejects = ["_main.scd", "settings.json"];
	var files = path.entries.select{|x| x.isFile && rejects.indexOfEqual(x.fileName).isNil };

	~recBuf = { Buffer.alloc(s, 44100 * 0.5, 1) }.dup;

	~playBus = Bus.audio(s,2);
	~grainBus = Bus.audio(s,2);
	~vars = Bus.control(s,18);
	
	~params = [
		// grain parameters
		"disp", 		// buf 0
		"bufPos",		// buf 1
		"dur",			// buf 2 
		"dens", 		// buf 3
		"portamnt",		// buf 4 *also a mix parameter
		// mixing parameters
		"mix",			// buf 5
		"ffreq",		// buf 6
		"rq",			// buf 7
		"fx wet",		// buf 8
		"pregain",		// buf 9
		"master",		// buf 10
		// flanger parameters
		"fl rate",		// buf 11
		"fl delay", 	// buf 12
		"fl depth", 	// buf 13
		// recording feedback
		"feedback"		// buf 14
		];
	
	~envs = [
		(-1),
		Buffer.sendCollection(s, Env([0, 1, 0], [0.5, 0.5], \welch).discretize, 1),
		Buffer.sendCollection(s, Env([0, 1, 0], [0.001, 0.999], [\sin,-2]).discretize, 1),
		Buffer.sendCollection(s, Env([0, 1, 0], [0.5, 0.5], [2,-2]).discretize, 1),
	];
	
	// execute all the other project-related SCD-files
	files.do{|x|

		x.fileName.postln;
		this.executeFile(x.fullPath);
	    0.1.wait;
	};

	~displayOSC.sendMsg('/main_menu', 0);
	
});
ServerQuit.add({ 0.exit }); // quit if the button is pressed
