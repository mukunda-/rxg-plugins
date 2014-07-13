
//-------------------------------------------------------------------------------------------------
#include <sourcemod>


//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = 
{
	name = "portalpotty",
	author = "mukunda",
	description = "Portal Potty (TM)",
	version = "1.0.0",
	url = "http://www.mukunda.com/"
}

new Handle:instances;

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	instances = CreateArray();
	RegConsoleCmd( "pp_test", test );
}

//-------------------------------------------------------------------------------------------------
public Action:test( client, args ) {
	
}

//-------------------------------------------------------------------------------------------------
public OnGameFrame() {
	for( new i = 0; i < GetArraySize( instances ); ) {
		
	}
}