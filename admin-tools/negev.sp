#include <sourcemod>
#include <sdktools>

//----------------------------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "negev",
	author = "reflex-gamers",
	description = "negev",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

public OnPluginStart() {
	RegAdminCmd( "sm_negev", Negev, ADMFLAG_RCON );
}

public Action:Negev( client, args ) {
	GivePlayerItem( client ,"weapon_negev" );
	return Plugin_Handled;
}
