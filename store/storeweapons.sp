
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2items_giveweapon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "RXG TF2 Store Weapons",
	author = "WhiteThunder",
	description = "give weapons to players via the store",
	version = "0.8",
	url = "www.reflex-gamers.com"
};

#define MAX_ACTIVE_WEAPONS 2
#define CUSTOM_WEAPON_COOLDOWN 60.0

new g_num_active_weapons;
new g_client_weapon[MAXPLAYERS+1];
new Float:g_last_used[MAXPLAYERS+1];


//-----------------------------------------------------------------------------
public OnPluginStart() {
	RegAdminCmd( "sm_givestoreweapon", Command_GiveStoreWeapon, ADMFLAG_RCON );
	HookEvent( "post_inventory_application", LockerWepReset,  EventHookMode_Post );
	HookEvent( "player_death", Event_PlayerDeath );
	//HookEvent( "player_spawn", Event_PlayerSpawn );
	//HookEvent( "teamplay_round_start", Event_RoundStart );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_weapon[i] = 0;
		g_last_used[i] = -CUSTOM_WEAPON_COOLDOWN;
	}
	
	g_num_active_weapons = 0;
}

//-----------------------------------------------------------------------------
public Action:Command_GiveStoreWeapon( client, args ) {
	
	if (args != 2) {
		ReplyToCommand(client, "[StoreWeapons] Usage: sm_givstoreeweapon <player> <itemindex>");
		return Plugin_Handled;
	}

	new String:arg1[32];
	new String:arg2[32];
	
	GetCmdArg(1, arg1, sizeof(arg1));
	GetCmdArg(2, arg2, sizeof(arg2));
	new weapon_index = StringToInt(arg2);
	
	new String:target_name[MAX_TARGET_LENGTH];
	new target_list[MAXPLAYERS], target_count, bool:tn_is_ml;
	
	if ((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE, /* Only allow alive players */
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0) {
		/* This function replies to the admin with a failure message */
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		GiveWeapon(target_list[i], weapon_index, "Special Weapon");
		LogAction(client, target_list[i], "\"%L\" gave weapon %d to \"%L\"", client, weapon_index, target_list[i]);
	}
	
	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
public OnClientDisconnect( client ) {
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public Action:Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public ResetClientWeapon( client ) {
	if ( g_client_weapon[client] != 0 ) {
		g_client_weapon[client] = 0;
		g_num_active_weapons--;
	}
}

//-----------------------------------------------------------------------------
public Event_PlayerSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public LockerWepReset( Handle:event, const String:name[], bool:dontBroadcast ) {
	CreateTimer( 0.1, Timer_LockerWeaponReset, GetEventInt( event, "userid" ) );
}

//-----------------------------------------------------------------------------
public Action:Timer_LockerWeaponReset( Handle:timer, any:userid ) {
	new client = GetClientOfUserId(userid);
	if ( IsValidClient(client) && IsPlayerAlive(client) ) {
		if (g_client_weapon[client] != 0) {
			TF2Items_GiveWeapon( client, g_client_weapon[client] );
		}
	}
}

//-----------------------------------------------------------------------------
bool:GiveWeapon( client, weapon_index, const String:weapon_name[] ) {
	
	if ( g_client_weapon[client] != 0 ) {
		PrintToChat( client, "\x07FFD800You already have a Special Weapon equipped!" );
		return false;
	}

	if ( g_num_active_weapons >= MAX_ACTIVE_WEAPONS ) {
		PrintToChat( client, "\x07FFD800There are too many active Special Weapons right now! Please try again later." );
		return false;
	}
	
	new Float:time = GetGameTime();
	if ( time < g_last_used[client] + CUSTOM_WEAPON_COOLDOWN ) {
		PrintToChat( client, "\x07FFD800You recently used a Special Weapon and must wait." );
		return false;
	}
	
	TF2Items_GiveWeapon(client, weapon_index);
	g_last_used[client] = time;
	g_client_weapon[client] = weapon_index;
	g_num_active_weapons++;
	
	decl String:team_color[7];
	new client_team = GetClientTeam(client);
	
	if( client_team == 2 ){
		team_color = "ff3d3d";
	} else if( client_team == 3 ){
		team_color = "84d8f4";
	}
	
	decl String:player_name[32];
	GetClientName( client, player_name, sizeof player_name );
	
	PrintToChatAll( "\x07%s%s \x07FFD800has equipped a \x073eFF3e%s!", team_color, player_name, weapon_name );
	
	return true;
}

//-----------------------------------------------------------------------------
stock bool:IsValidClient( client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}

