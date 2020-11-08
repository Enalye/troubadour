/** 
 * Copyright: Enalye
 * License: Zlib
 * Authors: Enalye
 */
import std.stdio, std.exception;

import troubadour.startup;

void main(string[] args) {
	try {
		setupApplication(args);
	}
	catch(Exception e) {
		writeln(e.msg);
		foreach(trace; e.info) {
			writeln("at: ", trace);
		}
	}
}
