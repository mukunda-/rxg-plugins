#if defined _rxgcommon_included
	#endinput
#endif

#define _rxgcommon_included

//-----------------------------------------------------------------------------
stock bool IsValidClient( client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}

//-----------------------------------------------------------------------------
stock WritePackHandle( Handle pack, Handle hndl ) {
	WritePackCell( pack, hndl );
}

//-----------------------------------------------------------------------------
stock Handle ReadPackHandle( Handle pack ) {
	return view_as<Handle>ReadPackCell( pack );
}

//-----------------------------------------------------------------------------
stock void CopyVector( float source[3], float destination[3] ) {
	destination[0] = source[0];
	destination[1] = source[1];
	destination[2] = source[2];
}

//-----------------------------------------------------------------------------
stock void FormatNumberInt( int value, char[] buffer, int size, 
                            int separator = ',') {
                            
    char[] helper = new char[size];
    IntToString(value, helper, size);
    strcopy(buffer, size, helper);

    int length = strlen(helper);

    int n_helper;

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

    int n_buffer = n_helper;

    while (n_helper < length) {
        buffer[n_buffer] = separator;
        strcopy(buffer[n_buffer + 1], size, helper[n_helper]);

        n_buffer += 4;
        n_helper += 3;
    }
}  

//-----------------------------------------------------------------------------
stock int intmin( int a, int b ) {
	return a < b ? a : b;
}

//-----------------------------------------------------------------------------
stock int intmax( int a, int b ) {
	return a > b ? a : b; 
}
//-----------------------------------------------------------------------------
stock int GetCmdArgInt( int index ) {
	char number[16];
	GetCmdArg( index, number, sizeof number );
	return StringToInt( number );
}
//-----------------------------------------------------------------------------
bool IntArrayContains(int val, int[] array, int arraySize){
	for (int i = 0; i < arraySize;i++){
		if(val == array[i]){
			return true;
		}
	}
	return false;
}