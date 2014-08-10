
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2_stocks>
#include <tf2items_giveweapon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "RXG Store Weapons",
	author = "WhiteThunder",
	description = "Equip weapons from the RXG Store",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

new Handle:sm_storeweapons_max_per_team;
new Handle:sm_storeweapons_restrict_class;
new Handle:sm_storeweapons_equip_cooldown;

new c_max_per_team;
new bool:c_restrict_class;
new Float:c_equip_cooldown;

new g_client_weapon[MAXPLAYERS+1];
new Float:g_last_used[MAXPLAYERS+1];
new TFTeam:g_client_team[MAXPLAYERS+1];
new g_num_red_weapons;
new g_num_blu_weapons;

new g_client_userid[MAXPLAYERS+1];

new String:class_names[][] = {
	"Unknown",
	"Scout",
	"Sniper",
	"Soldier",
	"DemoMan",
	"Medic",
	"Heavy",
	"Pyro",
	"Spy",
	"Engineer"
};

//-------------------------------------------------------------------------------------------------
public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max) {
	CreateNative( "STOREWEAPONS_GiveWeapon", Native_GiveWeapon );
	//RegAdminCmd( "sm_givestoreweapon", Command_GiveStoreWeapon, ADMFLAG_RCON );
	RegPluginLibrary("storeweapons");
}

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_max_per_team = GetConVarInt( sm_storeweapons_max_per_team );
	c_restrict_class = GetConVarBool( sm_storeweapons_restrict_class );
	c_equip_cooldown = GetConVarFloat( sm_storeweapons_equip_cooldown );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public OnPluginStart() {
	
	sm_storeweapons_max_per_team = CreateConVar( "sm_storeweapons_max_per_team", "2", "Maximum number of Store Weapons allowed per team at once. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_storeweapons_restrict_class = CreateConVar( "sm_storeweapons_restrict_class", "1", "Whether to restrict Store Weapons by class.", FCVAR_PLUGIN );
	sm_storeweapons_equip_cooldown = CreateConVar( "sm_storeweapons_equip_cooldown", "60", "Cooldown time between equipping Store Weapons.", FCVAR_PLUGIN, true, 0.0 );
	HookConVarChange( sm_storeweapons_max_per_team, OnConVarChanged );
	HookConVarChange( sm_storeweapons_restrict_class, OnConVarChanged );
	HookConVarChange( sm_storeweapons_equip_cooldown, OnConVarChanged );
	RecacheConvars();

	HookEvent( "post_inventory_application", Event_LockerReset,  EventHookMode_Post );
	HookEvent( "player_changeclass", Event_ChangeClass );
	HookEvent( "player_death", Event_PlayerDeath );
	//HookEvent( "player_spawn", Event_PlayerSpawn );
	//HookEvent( "teamplay_round_start", Event_RoundStart );
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_weapon[i] = 0;
		g_last_used[i] = -c_equip_cooldown;
	}
	
	g_num_red_weapons = 0;
	g_num_blu_weapons = 0;
}

//-------------------------------------------------------------------------------------------------
public Native_GiveWeapon( Handle:plugin, numParams ) {
	new client = GetNativeCell(1);
	new weapon_index = GetNativeCell(2);
	new TFClassType:class_restriction = GetNativeCell(3);
	
	new name_length;
	GetNativeStringLength( 4, name_length );
	if( name_length <= 0 ) {
		return false;
	}
	new String:weapon_name[name_length + 1];
	GetNativeString(4, weapon_name, name_length + 1);
	
	new text_color_length;
	GetNativeStringLength( 5, text_color_length );
	if( text_color_length <= 0 ) {
		return false;
	}
	new String:weapon_text_color[text_color_length + 1];
	GetNativeString(5, weapon_text_color, text_color_length + 1);
	
	return GiveWeapon( client, weapon_index, class_restriction, weapon_name, weapon_text_color );
}

//-----------------------------------------------------------------------------
public OnClientDisconnect( client ) {
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public Action:Event_PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public Action:Event_ChangeClass( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId( GetEventInt( event, "userid" ) );
	ResetClientWeapon(client);
}

//-----------------------------------------------------------------------------
public ResetClientWeapon( client ) {
	if( g_client_weapon[client] != 0 ) {
		g_client_weapon[client] = 0;
		
		if( g_client_team[client] == TFTeam_Red ) {
			g_num_red_weapons--;
		} else if( g_client_team[client] == TFTeam_Blue ) {
			g_num_blu_weapons--;
		}
	}
}

//-----------------------------------------------------------------------------
public Event_LockerReset( Handle:event, const String:name[], bool:dontBroadcast ) {
	CreateTimer( 0.1, Timer_LockerReset, GetEventInt( event, "userid" ) );
}

//-----------------------------------------------------------------------------
public Action:Timer_LockerReset( Handle:timer, any:userid ) {
	new client = GetClientOfUserId(userid);
	if( IsValidClient(client) && IsPlayerAlive(client) ) {
		if(g_client_weapon[client] != 0) {
			TF2Items_GiveWeapon( client, g_client_weapon[client] );
		}
	}
}

//-----------------------------------------------------------------------------
bool:GiveWeapon( client, weapon_index, TFClassType:class_restriction, const String:weapon_name[], const String:weapon_text_color[] ) {
	
	new userid = GetClientUserId(client);
	
	if( g_client_userid[client] != userid ) {
	
		//Client index changed hands
		g_client_userid[client] = userid;
		g_last_used[client] = -c_equip_cooldown;
		ResetClientWeapon(client);
		
	} else if( g_client_weapon[client] != 0 ) {
	
		PrintToChat( client, "\x07FFD800You already have a Store Weapon equipped!" );
		return false;
	}
	
	new TFTeam:client_team = TFTeam:GetClientTeam(client);
	
	if( c_max_per_team != 0 && (
			( client_team == TFTeam_Red && g_num_red_weapons >= c_max_per_team ) ||
			( client_team == TFTeam_Blue && g_num_blu_weapons >= c_max_per_team ) ) ) {
		PrintToChat( client, "\x07FFD800Only \x073EFF3E%d \x07FFD800active Store Weapons are allowed per team! Please try again later.", c_max_per_team );
		return false;
	}
	
	if( c_restrict_class && TF2_GetPlayerClass(client) != class_restriction ) {
		PrintToChat( client, "\x07FFD800Only the \x073EFF3E%s \x07FFD800class may use the \x07%s%s!", class_names[class_restriction], weapon_text_color, weapon_name );
		return false;
	}
	
	new Float:time = GetGameTime();
	new Float:next_use = g_last_used[client] + c_equip_cooldown;
	
	if( time < next_use ) {
		PrintToChat( client, "\x07FFD800Please wait \x073EFF3E%d \x07FFD800seconds before equipping another Store Weapon.", RoundToCeil(next_use - time) );
		return false;
	}
	
	if( !TF2Items_CheckWeapon(weapon_index) ) {
		PrintToChat( client, "\x07FFD800Oops! The \x07%s%s \x07FFD800is missing on this server. Please contact an administrator.", weapon_text_color, weapon_name );
		return false;
	}
	
	TF2Items_GiveWeapon(client, weapon_index);
	g_last_used[client] = time;
	g_client_weapon[client] = weapon_index;
	g_client_team[client] = client_team;
	
	decl String:team_color[7];
	
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
		g_num_red_weapons++;
	} else if( client_team == TFTeam_Blue ) {
		team_color = "84d8f4";
		g_num_blu_weapons++;
	} else {
		team_color = "ffffff";
	}
	
	decl String:player_name[32];
	GetClientName( client, player_name, sizeof player_name );
	
	PrintToChatAll( "\x07%s%s \x07FFD800has equipped a \x07%s%s!", team_color, player_name, weapon_text_color, weapon_name );
	
	return true;
}

//-----------------------------------------------------------------------------
stock bool:IsValidClient( client ) {
	return ( client > 0 && client <= MaxClients && IsClientInGame(client) );
}


/*
//-----------------------------------------------------------------------------
public Action:Command_GiveStoreWeapon( client, args ) {
	
	if(args != 2) {
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
	
	if((target_count = ProcessTargetString(
			arg1,
			client,
			target_list,
			MAXPLAYERS,
			COMMAND_FILTER_ALIVE, // Only allow alive players
			target_name,
			sizeof(target_name),
			tn_is_ml)) <= 0) {
		// This function replies to the admin with a failure message
		ReplyToTargetError(client, target_count);
		return Plugin_Handled;
	}
	
	for (new i = 0; i < target_count; i++)
	{
		GiveWeapon(target_list[i], weapon_index, TFClass_Unknown, "Store Weapon", "3EFF3E");
		LogAction(client, target_list[i], "\"%L\" gave weapon %d to \"%L\"", client, weapon_index, target_list[i]);
	}
	
	return Plugin_Handled;
}
*/
