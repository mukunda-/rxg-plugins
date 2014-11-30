#if defined _rxgcommon_included
	#endinput
#endif

#define _rxgcommon_included

//-------------------------------------------------------------------------------------------------
stock WritePackHandle( Handle:pack, Handle:hndl ) {
	WritePackCell( pack, hndl );
}

//-------------------------------------------------------------------------------------------------
stock Handle:ReadPackHandle( Handle:pack ) {
	return Handle:ReadPackCell( pack );
}

//-------------------------------------------------------------------------------------------------
stock CopyVector( Float:source[3], Float:destination[3] ) {
	destination[0] = source[0];
	destination[1] = source[1];
	destination[2] = source[2];
}

//-----------------------------------------------------------------------------
stock FormatDuration( duration, String:output[], maxlen ) {
	if( duration < 60 ) {
		FormatEx( output, maxlen, "%d second%s", 
			duration, duration == 1 ? "":"s" );
	} else if( duration < 60*60 ) {
		duration = duration / 60;
		FormatEx( output, maxlen, "%d minute%s", 
			duration, duration == 1 ? "":"s" );
	} else if( duration < 60*60*24 ) {
		duration = duration / (60*60);
		FormatEx( output, maxlen, "%d hour%s", 
			duration, duration == 1 ? "":"s" );
	} else {
		duration = duration / (60*60*24);
		FormatEx( output, maxlen, "%d day%s", 
			duration, duration == 1 ? "":"s" );
	}
}