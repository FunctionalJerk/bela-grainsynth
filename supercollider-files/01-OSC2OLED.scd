
//~truths = [fader1, fader2, fader3, preset, env, loop];

OSCdef(\enc, {|msg|

	var key, pointer, message;
	var which = msg[2];
	var vals = msg[3..];
	var val = vals[which].asInteger;
	var keys = ['/main_menu', '/fadermap', '/presets', '/var', '/shutdown'];
	var envs = ['Hann', 'Welch', 'Perc', 'Spike'];
	var check = [9,13,17,21];
	
	if(which == 0) {
		// encoder value changed:
		switch(~mode,
			0, {	// main-menu
				~selector = ~selector + val % 5;
				message = [~selector];
				key = keys[0];
			},
			1, {	// fader mapping
				~selector = (~selector + val % 10).max(5);
				message = [ ~selector - 5 ] ++ ~params[~truths[..2]];
				key = keys[1];
			},
			2, { 	// preset options
				~selector = (~selector + val % 14).max(10);
				message = [ ~selector - 10 ] ++ ~truths[3].dup;
				key = keys[2];
			},
			3, {	// var options
				~selector = (~selector + val % 18).max(14);
				message = [ ~selector - 14, envs[~truths[4]], ~truths[5].asBoolean.asString ];
				key = keys[3];
			},
			4, {	// shutdown options
				~selector = (~selector + val % 22).max(18);
				message = [ ~selector - 18 ];
				key = keys[4];
			},
			// 5, {  }, // empty

		);
		// map fader 1-3 (display choice-selection)
		if( (~mode >= 7) && (~mode < 10) ) {
			~selector = (~selector + val % 40).max(25);
			message = [ ~mode - 6, ~params[~truths[0]], ~params[~truths[1]], ~params[~truths[2]] ];
			message.put(message[0], ~params[~selector - 25]);
			key = keys[1]
		};
		// save / load preset
		if( (~mode == 12) || (~mode == 13) ) {
			~selector = (~selector + val % 50).max(40);
			message = [~mode - 11, ~truths[3], ~truths[3]];
			message.put(message[0], ~selector - 40);
			key = keys[2]
		};
		// var envbuf
		if( ~mode == 16 ) {
			~selector = (~selector + val % 54).max(50);
			message = [ 1, envs[~selector - 50], ~truths[5].asBoolean.asString ];
			key = keys[3]
		};
		// var looprec
		if( ~mode == 17 ) {
			~selector = (~selector + val % 56).max(54);
			message = [ 2, envs[~truths[4]], (~selector - 54).asBoolean.asString ];
			key = keys[3]
		};
		// error
		if( (~mode == 5) || (~mode == 6) || (~mode ==  10) || (~mode ==  11) || (~mode ==  14) || (~mode ==  15) || (~mode >= 18 ) ) {
			~selector = 0;
			~mode = 0;
			key = keys[0]; 
			message = [0]
		}
	////////////////////////////////////////////////////////////////////////////////////////
	} { 	// if button pressed:
		if( ~selector < 5 ) {
			switch(~selector, 
				// 0 -> main_menu; 1 -> fadermap; 2 -> presets; 3 -> vars; 4 -> shutdown
				0, { ~mode = 0; key = keys[0]; message = [0] },
				1, { ~mode = ~selector; key = keys[1]; message = [0] ++ ~params[~truths[..2]]; ~selector = 0 },
				2, { ~mode = ~selector; key = keys[2]; message = [0, ~truths[3], ~truths[3]]; ~selector = 0 },
				3, { ~mode = ~selector; key = keys[3]; message = [0, envs[~truths[4]], ~truths[5].asBoolean.asString ]; ~selector = 0 },
				4, { ~mode = ~selector; key = keys[4]; message = [0]; ~selector = 0 },
			);
		};
		if( (~selector >= 5) && (~selector < 22) ) {
			if( check.find([~selector]).notNil ) {
				
				~mode = 0; 
				key = keys[0]; 
				message = [0];
				~selector = 0;
				// 5-7 -> which fader to map
				// 9 & 10 -> preset options
				// 12 & 13 -> var options
				// 15 & 16 -> shutdown options

			} { 
				~mode = ~selector + 1;  
				switch(~selector, 
					6, { message = [ ~mode - 6, ~params[~truths[0]], ~params[~truths[1]], ~params[~truths[2]] ]; key = keys[1] },
					7, { message = [ ~mode - 6, ~params[~truths[0]], ~params[~truths[1]], ~params[~truths[2]] ]; key = keys[1] },
					8, { message = [ ~mode - 6, ~params[~truths[0]], ~params[~truths[1]], ~params[~truths[2]] ]; key = keys[1] },
					
					11, { message = [ ~selector - 10 ] ++ ~truths[3].dup; key = keys[2]; ~selector = ~truths[3] + 40}, 
					12, { message = [ ~selector - 10 ] ++ ~truths[3].dup; key = keys[2]; ~selector = ~truths[3] + 40 },
					
					15, { message = [ 1, envs[~selector - 50], ~truths[5].asBoolean.asString ];	key = keys[3] },
					16, { message = [ 2, envs[~selector - 50], ~truths[5].asBoolean.asString ]; key = keys[3] },
					
					19, { 
						p = Pipe.new("sudo reboot", "w");
						"reboot initated".postln;
						p.close;
						0.exit 
					},
					20, { 
						p = Pipe.new("shutdown now", "w");
						"shutdown initated".postln;
						p.close;
						0.exit 
					}
				)
			}
		} {
			if( ( (~selector >= 25) && (~selector < 40) ) ) {
	
				~map.set(~mode-6, ~selector - 25);
				~truths.put(~mode-7, ~selector - 25);
	
				~mode = 1;
				key = keys[~mode];
				message = [~mode-6] ++ ~params[~truths[..2]];
			};
			if( (~selector >= 40) && (~selector < 50) ) {
	
				~preset.(~selector - 40, ~mode - 12);
				~truths.put(3, ~selector - 40);

				key = keys[~mode];
				message = [0] ++ ~truths[3].dup;			
				~mode = 2;
			};
			if( (~selector >= 50) && (~selector < 54) ) {
	
				~grain.set(\envbuf, ~envs[~selector - 50]);
				~truths.put(4, ~selector - 50);
				
				~mode = 3;
				key = keys[~mode];
				message = [0, envs[~truths[4]], ~truths[5].asBoolean.asString];
			};
			if( (~selector >= 54) && (~selector < 56) ) {
	
				~grain.set(\latch, ~selector - 54);
				~truths.put(5, ~selector - 54);
	
				~mode = 3;
				key = keys[~mode];
				message = [0, envs[~truths[4]], ~truths[5].asBoolean.asString];		
			}
		}
	};
	[~selector, ~mode].postln;
	//[message, ~mode].postln;
	~displayOSC.sendMsg(key, *message)

}, '/dial', s.addr);

