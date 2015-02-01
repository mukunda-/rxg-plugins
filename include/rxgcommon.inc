#if defined _rxgcommon_included
	#endinput
#endif

#define _rxgcommon_included

//-----------------------------------------------------------------------------
stock bool:IsValidClient( client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}

//-----------------------------------------------------------------------------
stock WritePackHandle( Handle:pack, Handle:hndl ) {
	WritePackCell( pack, hndl );
}

//-----------------------------------------------------------------------------
stock Handle:ReadPackHandle( Handle:pack ) {
	return Handle:ReadPackCell( pack );
}

//-----------------------------------------------------------------------------
stock CopyVector( Float:source[3], Float:destination[3] ) {
	destination[0] = source[0];
	destination[1] = source[1];
	destination[2] = source[2];
}

//-----------------------------------------------------------------------------
stock FormatNumberInt(value, String:buffer[], size, separator=',') {
    decl String:helper[size];
    IntToString(value, helper, size);
    strcopy(buffer, size, helper);

    new length = strlen(helper);

    new n_helper;

    if (helper[0] == '-') {
        n_helper += ((length-1) % 3) + 1;

        if (n_helper == 1) {
            n_helper = 4;
        }
    }
    else {
        n_helper += length % 3;

        if (n_helper == 0) {
            n_helper = 3;
        }
    }

    new n_buffer = n_helper;

    while (n_helper < length) {
        buffer[n_buffer] = separator;
        strcopy(buffer[n_buffer + 1], size, helper[n_helper]);

        n_buffer += 4;
        n_helper += 3;
    }
}  