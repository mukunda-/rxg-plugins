
// bacon program definition

//-------------------------------------------------------------------------------------------------
#include <sourcemod>
#include <sdktools>

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "aug",
	author = "mukunda",
	description = "aug.",
	version = "1.0.0",
	url = "aug"
};

//-------------------------------------------------------------------------------------------------
new bool:aug_used[MAXPLAYERS+1];
#define AUG_COST 3300

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	RegConsoleCmd( "aug", aug );
	RegConsoleCmd( "quit", aug );
	HookEvent( "player_spawn", OnPlayerSpawn );
}

//-------------------------------------------------------------------------------------------------
public OnPlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	if( client == 0 ) return;
	aug_used[client] = false;
}

//-------------------------------------------------------------------------------------------------
public Action:aug( client, args ) {
	if( !IsClientInGame(client) || !IsPlayerAlive(client) ) 
		return Plugin_Handled;
	
	if( aug_used[client] ) {
		PrintToChat( client, "\x01 \x02Sorry, only one (1) AUG per person." );
		return Plugin_Handled;
	}
	
	if( GetEntProp( client, Prop_Send, "m_bInBuyZone" ) ) {
		new cash = GetEntProp( client, Prop_Send, "m_iAccount" );
		if( cash < AUG_COST ) {
			PrintToChat( client, "\x01 \x02Insufficient funds." );
			return Plugin_Handled;
		}
		SetEntProp( client, Prop_Send, "m_iAccount", cash - AUG_COST );
		GivePlayerItem( client, "weapon_aug" );
		PrintToChat( client, "\x01 \x0CHere is your AUG." );
		aug_used[client] = true;
	} else {
		PrintToChat( client, "\x01 \x02Not in buy zone." );
	}
	return Plugin_Handled;
}
