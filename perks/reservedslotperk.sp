
//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <donations>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Reserved Slot Perk",
	author = "mukunda",
	description = "Reserved Slot VIP Menu Item",
	version = "1.0.0",
	url = "www.mukunda.com"
};

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	VIP_Register( "Reserved Slots", OnVIPMenu );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded() {
	VIP_Register( "Reserved Slots", OnVIPMenu );
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd () {
	VIP_Unregister( );
	
}

//-------------------------------------------------------------------------------------------------
public OnVIPMenu( client, VIPAction:action ) {
	if( action == VIP_ACTION_HELP ) {
		PrintToChat( client, "\x01 \x04VIPs can join a game if it's full and extend the player limit. (On select RXG servers)" );
	} else if( action == VIP_ACTION_USE ) {
		PrintToChat( client, "\x01 \x04VIPs can join a game if it's full and extend the player limit. (On select RXG servers)" );
		PrintToChat( client, "\x01 \x04To join a full server, type \"connect <serverip>\" in console, and you will connect using a hidden slot." );
	}
}
