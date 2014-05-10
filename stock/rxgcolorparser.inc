
#if defined RXGCOLORPARSER_INC
#endinput
#endif
#define RXGCOLORPARSER_INC

#include <clientprefs>
 
//-------------------------------------------------------------------------------------------------
stock Saturate( value, min, max ) {
	if( value < min ) value = min;
	if( value > max ) value = max;
	return value;
}

//-------------------------------------------------------------------------------------------------
stock GetIntArg( index ) {
	decl String:arg[16];
	GetCmdArg(index,arg,sizeof(arg));
	return StringToInt(arg);
}

//-------------------------------------------------------------------------------------------------
new Handle:color_preset_trie = INVALID_HANDLE;

//-------------------------------------------------------------------------------------------------
new const String:color_preset_names[][] = {
	"red",		// 0
	"green",	// 1
	"blue",		// 2
	"orange",	// 3
	"yellow",	// 4
	"cyan",		// 5
	"white",	// 6
	"magenta",	// 7
	"pink"
};

//-------------------------------------------------------------------------------------------------
new const color_presets[] = {
	255,   0,   0,		// 0
	0,   255,   0,		// 1
	0,     0, 255,		// 2
	255, 128,   0,	// 3
	255, 255,   0,		// 4
	0,   255, 255,		// 5
	255, 255, 255,	// 6
	255,   0, 255,		// 7
	255,   0, 128
};


//-------------------------------------------------------------------------------------------------
stock parse_hexbyte( const String:code[] ) {
	new code0,code1;
	code0 = CharToLower(code[0]);
	code1 = CharToLower(code[1]);

	new result;
	if( (code0 >= '0' && code0 <= '9') ) {
		result += (code0-'0') * 16;
	} else if( (code0 >= 'a' && code0 <= 'f' ) ) {
		result += (code0-'a'+10) * 16;
	} else {
		return 255;
	}

	if( (code1 >= '0' && code1 <= '9') ) {
		result += (code1-'0');
	} else if( (code1 >= 'a' && code1 <= 'f' ) ) {
		result += (code1-'a'+10);
	} else {
		return 255;
	}

	return result;
}

//-------------------------------------------------------------------------------------------------
stock parse_digit( const String:code[] ) {
	new result;
	if( code[0] < '0' || code[0] > '9' ) return -1;
	result = code[0] - '0';
	result = result * 255 / 9;
	return result;
}

//-------------------------------------------------------------------------------------------------
stock bool:ParseColor( const String:arg[], color[3] ) {
    
	if( StrEqual( arg, "random" ) ) {
		color[0] = GetRandomInt(0, 255);
		color[1] = GetRandomInt(0, 255);
		color[2] = GetRandomInt(0, 255);
		return true;
	}
	
	if( color_preset_trie == INVALID_HANDLE ) {
		color_preset_trie = CreateTrie();
		for( new i = 0; i < sizeof( color_preset_names ); i++ ) {
			SetTrieValue( color_preset_trie, color_preset_names[i], i );
		}
	}
		
	new preset;
	if( GetTrieValue( color_preset_trie, arg, preset ) ) {
		for( new i = 0; i < 3; i++ ){
			color[i] = color_presets[ preset * 3 + i ];
		}
		return true;
	}
 
	new len = strlen(arg);
	if( len == 6 ) {
		// hexcode
		new r,g,b;
		r = parse_hexbyte( arg );
		g = parse_hexbyte( arg[2] );
		b = parse_hexbyte( arg[4] );
		if( r == -1 || g == -1 || b == -1 ) return false;
		color[0] = r; color[1] = g; color[2] = b;
		return true;
	} else if( len == 3 ) {
		// shortcode
		new r,g,b;
		r = parse_digit(arg);
		g = parse_digit(arg[1]);
		b = parse_digit(arg[2]);
		if( r == -1 || g == -1 || b == -1 ) return false;
		color[0] = r; color[1] = g; color[2] = b;
		return true;
	}
 
	return false;
}
