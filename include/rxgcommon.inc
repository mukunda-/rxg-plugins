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
