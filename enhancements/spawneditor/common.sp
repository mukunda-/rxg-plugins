
#define MAXSPAWNS 64

//-----------------------------------------------------------------------------
StripMapFolder( String:mapname[], maxlen ) {

	// an exotic way to strip workshop paths
	for(;;) {
		new pos;
		pos = FindCharInString( mapname, '/', true );
		if( pos != -1 ) {
			Format( mapname, maxlen, mapname[pos+1] );
			continue;
		}
		
		pos = FindCharInString( mapname, '\\', true );
		if( pos != -1 ) {
			Format( mapname, maxlen, mapname[pos+1] );
			continue;
		}
		break;
	}
}

//-----------------------------------------------------------------------------
LoadPositions( Handle:kv, const String:key[], 
			   Float:vecs[MAXSPAWNS][3], Float:ang[MAXSPAWNS] ) {
	
	new count = 0;
	if( KvJumpToKey( kv, key )) {
		if( KvGotoFirstSubKey( kv )) {
			do {
				KvGetVector( kv, "pos", vecs[count] )
				ang[count] = KvGetFloat( kv, "ang" );
				count++;
			} while( KvGotoNextKey( kv ));
			KvGoBack( kv );
		}
		KvGoBack( kv );
	}
	return count;
}
