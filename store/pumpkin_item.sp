#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <rxgstore>
#include <tf2_stocks>
#include <pumpkin>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin myinfo = {
	name = "pumpkin item",
	author = "WhiteThunder",
	description = "plantable pumpkin bombs",
	version = "2.3.0",
	url = "www.reflex-gamers.com"
};


#define ITEM_NAME "pumpkin"
#define ITEM_FULLNAME "pumpkin"
#define ITEMID 6

Handle sm_pumpkins_max_per_player;
Handle sm_pumpkins_max_plant_distance;
Handle sm_pumpkins_broadcast_cooldown;

int c_max_per_player;
float c_max_plant_distance;
float c_broadcast_cooldown;

int g_client_userid[MAXPLAYERS+1];
float g_last_broadcast[MAXPLAYERS+1];


//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_max_per_player = GetConVarInt( sm_pumpkins_max_per_player );
	c_max_plant_distance = GetConVarFloat( sm_pumpkins_max_plant_distance );
	c_broadcast_cooldown = GetConVarFloat( sm_pumpkins_broadcast_cooldown );
}
//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] intval ) {
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	
	sm_pumpkins_max_per_player = CreateConVar( "sm_pumpkins_max_per_player", "15", "Maximum number of Pumpkin Bombs allowed per player at once. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_max_plant_distance = CreateConVar( "sm_pumpkins_max_plant_distance", "500", "The maximum distance you may plant Pumpkin Bombs away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_broadcast_cooldown = CreateConVar( "sm_pumpkins_broadcast_cooldown", "30", "How frequently to broadcast that a player is planing Pumpkin Bombs (per player).", FCVAR_PLUGIN, true, 0.0 );
	
	HookConVarChange( sm_pumpkins_max_per_player, OnConVarChanged );
	HookConVarChange( sm_pumpkins_max_plant_distance, OnConVarChanged );
	HookConVarChange( sm_pumpkins_broadcast_cooldown, OnConVarChanged );
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	for( int i = 1; i <= MaxClients; i++ ) {
		g_last_broadcast[i] = -c_broadcast_cooldown;
	}
}
//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const char[] name ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}
//-------------------------------------------------------------------------------------------------
bool SpawnPumpkin( client ) {
	
	int userid = GetClientUserId(client);
	
	if( g_client_userid[client] != userid ) {
		//Client index changed hands
		g_client_userid[client] = userid;
		g_last_broadcast[client] = -c_broadcast_cooldown;
	}
	
	if( !IsPlayerAlive(client) ){
		PrintToChat( client, "\x07FFD800Cannot plant when dead." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Cloaked ) ){
		PrintToChat( client, "\x07FFD800Cannot plant when cloaked." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Disguised ) ){
		PrintToChat( client, "\x07FFD800Cannot plant when disguised." );
		return false;
	}
	
	PMKN_SpawnPumpkinAtAim(client, c_max_plant_distance, c_max_per_player);
	
	char team_color[7];
	TFTeam client_team = TFTeam:GetClientTeam(client);
	
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
	} else if ( client_team == TFTeam_Blue ){
		team_color = "84d8f4";
	} else {
		team_color = "874fad";
	}
	
	
	
	char player_name[32];
	GetClientName(client, player_name, sizeof player_name);
	
	//Throttle broadcasts
	float time = GetGameTime();
	if( time >= g_last_broadcast[client] + c_broadcast_cooldown ) {
		PrintToChatAll( "\x07%s%s \x07FFD800is planting \x07FF6600Pumpkin Bombs!", team_color, player_name );
		g_last_broadcast[client] = time;
	}
	return true;
}
//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	return SpawnPumpkin(client);
}
