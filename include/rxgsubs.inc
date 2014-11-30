#if defined _rxgsubs_included
	#endinput
#endif
#define _rxgsubs_included

// TEXT SUBSTITUTIONS
//
// useful for color codes.

new Handle:g_subs_array = INVALID_HANDLE;

/** ---------------------------------------------------------------------------
 * Replace subs in a string.
 *
 * @param str    String to scan and modify.
 * @param maxlen Size of string.
 * @param strip  If true, strip subs instead of replacing them.
 */
stock FormatSubs( String:str[], maxlen, bool:strip = false ) {
	if( g_subs_array == INVALID_HANDLE ) return;
	new entries = GetArraySize( g_subs_array );
	
	decl String:replace[128];
	replace = ""; // for strip.
	
	for( new i = 0; i < entries; i++ ) {
		decl String:sub[128];
		GetArrayString( g_subs_array, i*2, sub, sizeof sub );
		
		if( !strip ) {
			GetArrayString( g_subs_array, i*2+1, replace, sizeof replace );
		}
		
		ReplaceString( str, maxlen, sub, replace );
	}
}

/** ---------------------------------------------------------------------------
 * Add a sub to scan for.
 *
 * @param replace String to replace.
 * @param value   String to substitute.
 */
stock AddSubFormat( String:replace[], String:sub[] ) {
	if( g_subs_array == INVALID_HANDLE ) {
		g_subs_array = CreateArray( 32 );
	}
	
	PushArrayString( g_subs_array, replace );
	PushArrayString( g_subs_array, sub     );
}
