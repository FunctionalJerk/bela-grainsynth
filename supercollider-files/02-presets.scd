
~preset = {|preset,mode=0|

	var file = ("GrainSynth_" ++ preset.asString ++ ".dat");
	var path = PathName("/root/Bela/projects/DasDing/presets" +/+ file);
	path = path.fullPath;

	if(mode == 0) {

		File.use(path, "wb", {|x|
			~truths.do{|y| x.putInt8(y) };
			~vars.getnSynchronous.do{|y| x.putFloat(y) };
			x.close
		})
	} {
		File.use(path, "rb", {|x|

			~truths = ~truths.collect{ x.getInt8 };
			// ~recBuf.do{|x| x.free };
			~vars.setn(18.collect{ x.getFloat });
			~map.setn(1, ~truths[..2]);
			~grain.set(\envbuf, ~truths[4], \latch, ~truths[5]);
			x.close;
		})
	}
}
