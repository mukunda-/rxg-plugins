
#include <sourcemod>
#include <rxgservices>
 
//-----------------------------------------------------------------------------
public Plugin:myinfo = {
//-----------------------------------------------------------------------------
	name = "shitmod4",
	author = "di",
	description = "shit mod v4",
	version = "1.0.0.0.4",
	url="ginger"
};
 
//-----------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "test1", Test );
}

//-----------------------------------------------------------------------------
public Action:Test( client, argc ) {
	PrintToServer( "rgstest" );
	RGS_RequestS( response, "TEST" );
	return Plugin_Handled;
}

public response( bool:error, String:data[] ) {

	PrintToServer( "TEST RESPONSE %s", data );
}