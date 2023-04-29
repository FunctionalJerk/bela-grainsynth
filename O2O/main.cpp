/*
 ____  _____ _        _
| __ )| ____| |      / \
|  _ \|  _| | |     / _ \
| |_) | |___| |___ / ___ \
|____/|_____|_____/_/   \_\

The platform for ultra-low latency audio and sensor processing

http://bela.io

A project of the Augmented Instruments Laboratory within the
Centre for Digital Music at Queen Mary University of London.
http://www.eecs.qmul.ac.uk/~andrewm

(c) 2016 Augmented Instruments Laboratory: Andrew McPherson,
  Astrid Bin, Liam Donovan, Christian Heinrichs, Robert Jack,
  Giulio Moro, Laurel Pardue, Victor Zappi. All rights reserved.

The Bela software is distributed under the GNU Lesser General Public License
(LGPL 3.0), available here: https://www.gnu.org/licenses/lgpl-3.0.txt
*/
/**
\example Communication/oled-screen/main.cpp

Working with OLED Screens and OSC
---------------------------------

*/

#include <signal.h>
#include <libraries/OscReceiver/OscReceiver.h>
#include <unistd.h>
#include "u8g2/U8g2LinuxI2C.h"
#include <vector>
#include <algorithm>

const unsigned int gI2cBus = 1;

// #define I2C_MUX // allow I2C multiplexing to select different target displays
struct Display {U8G2 d; int mux;};
std::vector<Display> gDisplays = {
	// use `-1` as the last value to indicate that the display is not behind a mux, or a number between 0 and 7 for its muxed channel number
	{ U8G2_SH1106_128X64_NONAME_F_HW_I2C_LINUX(U8G2_R0, gI2cBus, 0x3c), -1},
	// add more displays / addresses here
};

unsigned int gActiveTarget = 0;
const int gLocalPort = 7562; //port for incoming OSC messages

#ifdef I2C_MUX
#include "TCA9548A.h"
const unsigned int gMuxAddress = 0x70;
TCA9548A gTca;
#endif // I2C_MUX

/// Determines how to select which display a message is targeted to:
typedef enum {
	kTargetSingle, ///< Single target (one display).
	kTargetEach, ///< The first argument to each message is an index corresponding to the target display
	kTargetStateful, ///< Send a message to /target <float> to select which is the active display that all subsequent messages will be sent to
} TargetMode;

TargetMode gTargetMode = kTargetSingle; // can be changed with /targetMode
OscReceiver oscReceiver;
int gStop = 0;

// Handle Ctrl-C by requesting that the audio rendering stop
void interrupt_handler(int var)
{
	gStop = true;
}

static void switchTarget(int target)
{
#ifdef I2C_MUX
	if(target >= gDisplays.size())
		return;
	U8G2& u8g2 = gDisplays[target].d;
	int mux = gDisplays[target].mux;
	static int oldMux = -1;
	if(oldMux != mux)
		gTca.select(mux);
	oldTarget = target;
#endif // I2C_MUX
	gActiveTarget = target;
}

int parseMessage(oscpkt::Message msg, void*)
{
	int int1Value;
	int int2Value;
	int pointer; 
	
	oscpkt::Message::ArgReader args = msg.arg();
	enum {
		kOk = 0,
		kUnmatchedPattern,
		kWrongArguments,
		kInvalidMode,
		kOutOfRange,
	} error = kOk;
	bool stateMessage = false;
	// check state (non-display) messages first

	if (msg.match("/target")) {
		stateMessage = true;
		if(kTargetStateful != gTargetMode) {
			fprintf(stderr, "Target mode is not stateful, so /target messages are ignored\n");
			error = kInvalidMode;
		} else {
			int target;
			if(args.popNumber(target).isOkNoMoreArgs()) {
				printf("Selecting /target %d\n", target);
				switchTarget(target);
			} else {
				fprintf(stderr, "Argument to /target should be numeric (int or float)\n");
				error = kWrongArguments;
			}
		}
	} else if (msg.match("/targetMode")) {
		stateMessage = true;
		int mode;
		if(args.popNumber(mode).isOkNoMoreArgs())
		{
			if(mode != kTargetSingle && mode != kTargetStateful && mode != kTargetEach)
				error = kOutOfRange;
			else {
				gTargetMode = (TargetMode)mode;
				printf("Target mode: %d\n", mode);
			}
		} else
			error = kWrongArguments;
	}
	if(gActiveTarget >= gDisplays.size())
	{
		fprintf(stderr, "Target %u out of range. Only %u displays are available\n", gActiveTarget, gDisplays.size());
		return 1;
	}
	U8G2& u8g2 = gDisplays[gActiveTarget].d;
	u8g2.clearBuffer();
	int displayWidth = u8g2.getDisplayWidth();
	int displayHeight = u8g2.getDisplayHeight();
	if(!stateMessage && kTargetEach == gTargetMode)
	{
		// if we are in kTargetEach and the message is for a display, we need to peel off the
		// first argument (which denotes the target display) before processing the message
		int target;
		if(args.popNumber(target))
		{
			switchTarget(target);
		} else {
			fprintf(stderr, "Target mode is \"Each\", therefore the first argument should be an int or float specifying the target display\n");
			error = kWrongArguments;
		}
	}


	// code below MUST use msg.match() to check patterns and args.pop... or args.is ... to check message content.
	// this way, anything popped above (if we are in kTargetEach mode), won't be re-used below
	if(error || stateMessage) {
		// nothing to do here, just avoid matching any of the others
	} else if (msg.match("/booting")) 
	{
		if(!args.isOkNoMoreArgs()){
			error = kWrongArguments;
		} else {
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			u8g2.drawStr(displayWidth * 0.25, displayHeight * 0.5, "Booting...");
		}
	} else if (msg.match("/main_menu"))
	{
		if(!args.popInt32(pointer).isOkNoMoreArgs()){
			error = kWrongArguments;
		} else {

			// printf("received /osc-test\n");
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			u8g2.drawStr(16, 0, "MAP FADERS");
			u8g2.drawStr(16, displayHeight * 0.25, "PRESETS");
			u8g2.drawStr(16, displayHeight * 0.5, "OPTIONS");
			u8g2.drawStr(16, displayHeight * 0.75, "SHUTDOWN");

			switch(pointer) {
				case 0 : 
					break;
				case 1 : 
					u8g2.drawStr(0, displayHeight * 0.0, ">");
					break;
				case 2 : 
					u8g2.drawStr(0, displayHeight * 0.25, ">");
					break;
				case 3 : 
					u8g2.drawStr(0, displayHeight * 0.5, ">");
					break;
				case 4 : 
					u8g2.drawStr(0, displayHeight * 0.75, ">");
					break;
				default : 
					u8g2.drawStr(0, displayHeight * 0.75, ">");
			}
		}
	}  else if (msg.match("/fadermap"))
	{
		std::string text1;
		std::string text2;
		std::string text3;
		if(!args.popInt32(pointer).popStr(text1).popStr(text2).popStr(text3).isOkNoMoreArgs())
			error = kWrongArguments;
		else {
			const char *ctrStr1 = text1.c_str();
			const char *ctrStr2 = text2.c_str();
			const char *ctrStr3 = text3.c_str();

			// printf("received /parameters float %f float %f float %f\n", param1Value, param2Value, param3Value);
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			u8g2.drawStr(16, 10, "FDR1:");
			u8g2.drawUTF8(displayWidth * 0.5, 10, ctrStr1);
			u8g2.drawStr(16, 22, "FDR2:");
			u8g2.drawUTF8(displayWidth * 0.5, 22, ctrStr2);
			u8g2.drawStr(16, 34, "FDR3:");
			u8g2.drawUTF8(displayWidth * 0.5, 34, ctrStr3);
			u8g2.drawStr(16, 46, "BACK");

			switch(pointer) {
				case 0 : 
					break;
				case 1 : 
					u8g2.drawStr(0, 10, ">");
					break;
				case 2 : 
					u8g2.drawStr(0, 22, ">");
					break;
				case 3 : 
					u8g2.drawStr(0, 34, ">");
					break;
				case 4 : 
					u8g2.drawStr(0, 46, ">");
					break;
				default: 
					u8g2.drawStr(0, 46, ">"); 
			}
		}
	} else if (msg.match("/var"))
	{
		std::string text1;
		std::string text2;
		if(!args.popInt32(pointer).popStr(text1).popStr(text2).isOkNoMoreArgs())
			error = kWrongArguments;
		else {
			const char *ctrStr1 = text1.c_str();
			const char *ctrStr2 = text2.c_str();

			// printf("received /parameters float %f float %f float %f\n", param1Value, param2Value, param3Value);
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			u8g2.drawStr(16, 10, "ENV:");
			u8g2.drawUTF8(displayWidth * 0.5, 10, ctrStr1);
			u8g2.drawStr(16, 22, "LATCH:");
			u8g2.drawUTF8(displayWidth * 0.5, 22, ctrStr2);
			//u8g2.drawStr(16, 34, "FADER 3:");
			//u8g2.drawUTF8(displayWidth * 0.5, 34, ctrStr3);
			u8g2.drawStr(16, 46, "BACK");

			switch(pointer) {
				case 0 : 
					break;
				case 1 : 
					u8g2.drawStr(0, 10, ">");
					break;
				case 2 : 
					u8g2.drawStr(0, 22, ">");
					break;
				//case 3 : 
					//u8g2.drawStr(0, 34, ">");
					//break;
				case 3 : 
					u8g2.drawStr(0, 46, ">");
					break;
				default: 
					u8g2.drawStr(0, 46, ">"); 
			}
		}
	} else if (msg.match("/presets"))
	{
		if(!args.popInt32(pointer).popInt32(int1Value).popInt32(int2Value).isOkNoMoreArgs())
			error = kWrongArguments;
		else {
			//printf("received /parameters float %f float %f float %f\n", param1Value, param2Value, param3Value);
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			
			u8g2.drawStr(16, 10, "SAVE");
			u8g2.drawUTF8(displayWidth * 0.5, 10, std::to_string(int1Value).c_str());
			u8g2.drawStr(16, 22, "LOAD");
			u8g2.drawUTF8(displayWidth * 0.5, 22, std::to_string(int2Value).c_str());
			u8g2.drawStr(16, 46, "BACK");

			switch(pointer) {
				case 0 : 
					break;
				case 1 : 
					u8g2.drawStr(0, 10, ">");
					break;
				case 2 : 
					u8g2.drawStr(0, 22, ">");
					break;
				case 3 : 
					u8g2.drawStr(0, 46, ">");
					break;
				default : 
					u8g2.drawStr(0, 46, ">");
			}
		}
	} else if (msg.match("/shutdown"))
	{
		if(!args.popInt32(pointer).isOkNoMoreArgs()) 
			error = kWrongArguments;
		else {

			//printf("received /parameters float %f float %f float %f\n", param1Value, param2Value, param3Value);
			u8g2.setFont(u8g2_font_ncenB08_tr);
			u8g2.setFontRefHeightText();
			u8g2.drawStr(16, 10, "REBOOT");
			u8g2.drawStr(16, 22, "SHUTDOWN");
			u8g2.drawStr(16, 46, "BACK");

			switch(pointer) {
				case 0 : 
					break;
				case 1 : 
					u8g2.drawStr(0, 10, ">");
					break;
				case 2 : 
					u8g2.drawStr(0, 22, ">");
					break;
				//case 3 : 
					//u8g2.drawStr(0, 34, ">");
					//break;
				case 3 : 
					u8g2.drawStr(0, 46, ">");
					break;
				default: 
					u8g2.drawStr(0, 46, ">"); 
			}
		}
	} else
		error = kUnmatchedPattern;
	if(error)
	{
		std::string str;
		switch(error){
			case kUnmatchedPattern:
				str = "no matching pattern available\n";
				break;
			case kWrongArguments:
				str = "unexpected types and/or length\n";
				break;
			case kInvalidMode:
				str = "invalid target mode\n";
				break;
			case kOutOfRange:
				str = "argument(s) value(s) out of range\n";
				break;
			case kOk:
				str = "";
				break;
		}
		// fprintf(stderr, "An error occurred with message to: %s: %s\n", msg.addressPattern().c_str(), str.c_str());
		return 1;
	} else
	{
		if(!stateMessage)
			u8g2.sendBuffer();
	}
	return 0;
};

int main(int main_argc, char *main_argv[])
{
	if(0 == gDisplays.size())
	{
		fprintf(stderr, "No displays in gDisplays\n");
		return 1;
	}
#ifdef I2C_MUX
	if(gTca.initI2C_RW(gI2cBus, gMuxAddress, -1) || gTca.select(-1))
	{
		fprintf(stderr, "Unable to initialise the TCA9548A multiplexer. Are the address and bus correct?\n");
		return 1;
	}
#endif // I2C_MUX
	for(unsigned int n = 0; n < gDisplays.size(); ++n)
	{
		switchTarget(n);
		U8G2& u8g2 = gDisplays[gActiveTarget].d;
#ifndef I2C_MUX
		int mux = gDisplays[gActiveTarget].mux;
		if(-1 != mux)
		{
			fprintf(stderr, "Display %u requires mux %d but I2C_MUX is disabled\n", n, mux);
			return 1;
		}
#endif // I2C_MUX
		
		u8g2.initDisplay();
		u8g2.setPowerSave(0);
		u8g2.clearBuffer();
		u8g2.setFont(u8g2_font_4x6_tf);
		u8g2.setFontRefHeightText();
		u8g2.setFontPosTop();
		u8g2.drawStr(0, 0, " ____  _____ _        _");
		u8g2.drawStr(0, 7, "| __ )| ____| |      / \\");
		u8g2.drawStr(0, 14, "|  _ \\|  _| | |     / _ \\");
		u8g2.drawStr(0, 21, "| |_) | |___| |___ / ___ \\");
		u8g2.drawStr(0, 28, "|____/|_____|_____/_/   \\_\\");
		
		if(gDisplays.size() > 1)
		{
			std::string targetString = "Target ID: " + std::to_string(n);
			u8g2.drawStr(0, 50, targetString.c_str());
		}
		u8g2.sendBuffer();
	}
	// Set up interrupt handler to catch Control-C and SIGTERM
	signal(SIGINT, interrupt_handler);
	signal(SIGTERM, interrupt_handler);
	// OSC
	oscReceiver.setup(gLocalPort, parseMessage);
	while(!gStop)
	{
		usleep(100000);
	}
	return 0;
}

