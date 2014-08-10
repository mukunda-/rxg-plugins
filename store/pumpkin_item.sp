 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "pumpkin item",
	author = "WhiteThunder",
	description = "plantable pumpkin bombs",
	version = "2.2.0",
	url = "www.reflex-gamers.com"
};

#define PUMPKIN_PLANT_SOUND "items/pumpkin_drop.wav"
#define PUMPKIN_ARM_SOUND "misc/doomsday_warhead.wav"

new Handle:sm_pumpkins_max_per_player;
new Handle:sm_pumpkins_max_plant_distance;
new Handle:sm_pumpkins_broadcast_cooldown;
new Handle:sm_pumpkins_arm_delay;
new Handle:sm_pumpkins_arm_solid;

new c_max_per_player;
new Float:c_max_plant_distance;
new Float:c_broadcast_cooldown;
new Float:c_arm_delay;
new bool:c_arm_solid;

#define MAXENTITIES 2048

new g_pumpkin_userid[MAXENTITIES];
new bool:g_pumpkin_taking_damage[MAXENTITIES];
new Float:g_pumpkin_spawn_time[MAXENTITIES];

new g_client_userid[MAXPLAYERS+1];
new g_client_pumpkins[MAXPLAYERS+1];
new Float:g_last_broadcast[MAXPLAYERS+1];

#define ITEM_NAME "pumpkin"
#define ITEM_FULLNAME "pumpkin"
#define ITEMID 6

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_max_per_player = GetConVarInt( sm_pumpkins_max_per_player );
	c_max_plant_distance = GetConVarFloat( sm_pumpkins_max_plant_distance );
	c_broadcast_cooldown = GetConVarFloat( sm_pumpkins_broadcast_cooldown );
	c_arm_delay = GetConVarFloat( sm_pumpkins_arm_delay );
	c_arm_solid = GetConVarBool( sm_pumpkins_arm_solid );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	
	sm_pumpkins_max_per_player = CreateConVar( "sm_pumpkins_max_per_player", "15", "Maximum number of Pumpkin Bombs allowed per player at once. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_max_plant_distance = CreateConVar( "sm_pumpkins_max_plant_distance", "500", "The maximum distance you may plant Pumpkin Bombs away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_broadcast_cooldown = CreateConVar( "sm_pumpkins_broadcast_cooldown", "30", "How frequently to broadcast that a player is planing Pumpkin Bombs.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_arm_delay = CreateConVar( "sm_pumpkins_arm_delay", "0.9", "Time in seconds required for a Pumpkin Bomb to arm after being planted.", FCVAR_PLUGIN, true, 0.0, true, 5.0 );
	sm_pumpkins_arm_solid = CreateConVar( "sm_pumpkins_arm_solid", "1", "Whether Pumpkin Bombs should become solid when armed.", FCVAR_PLUGIN );
	
	HookConVarChange( sm_pumpkins_max_per_player, OnConVarChanged );
	HookConVarChange( sm_pumpkins_max_plant_distance, OnConVarChanged );
	HookConVarChange( sm_pumpkins_broadcast_cooldown, OnConVarChanged );
	HookConVarChange( sm_pumpkins_arm_delay, OnConVarChanged );
	HookConVarChange( sm_pumpkins_arm_solid, OnConVarChanged );
	RecacheConvars();
	
	RegAdminCmd( "sm_spawnpumpkin", Command_spawnpumpkin, ADMFLAG_RCON );
	HookEvent( "teamplay_round_start", Event_RoundStart );
}

//-------------------------------------------------------------------------------------------------
public OnLibraryAdded( const String:name[] ) {
	if( StrEqual( name, "rxgstore" ) ) {
		RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
	}
}

//-------------------------------------------------------------------------------------------------
public OnPluginEnd() {
	RXGSTORE_UnregisterItem( ITEMID );
}

//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	for( new i = 1; i <= MaxClients; i++ ) {
		g_last_broadcast[i] = -c_broadcast_cooldown;
	}
	PrecacheSound( PUMPKIN_PLANT_SOUND );
	PrecacheSound( PUMPKIN_ARM_SOUND );
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	for( new i = 1; i <= MaxClients; i++ ) {
		g_client_pumpkins[i] = 0;
	}
}

//-------------------------------------------------------------------------------------------------
public Action:Command_spawnpumpkin( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnPumpkin(client);
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
bool:SpawnPumpkin( client ) {
	
	new userid = GetClientUserId(client);
	
	if( g_client_userid[client] != userid ) {
	
		//Client index changed hands
		g_client_userid[client] = userid;
		g_client_pumpkins[client] = 0;
		g_last_broadcast[client] = -c_broadcast_cooldown;
		
	} else if( c_max_per_player != 0 && g_client_pumpkins[client] >= c_max_per_player ) {
	
		PrintToChat( client, "\x07FFD800You may not have more than \x073EFF3E%i \x07FF6600Pumpkins \x07FFD800planted at once.", c_max_per_player );
		return false;
	}
	
	decl Float:start[3], Float:angle[3], Float:end[3], Float:feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		decl Float:norm[3], Float:norm_angles[3];
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		new Float:distance = GetVectorDistance( feet, end, true );

		if ( c_max_plant_distance != 0 && distance > c_max_plant_distance * c_max_plant_distance ) {
			PrintToChat( client, "\x07FFD800Cannot plant that far away." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if ( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot plant there." );
			RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
	}
	
	new ent = CreateEntityByName( "tf_pumpkin_bomb" );
	
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	SetEntityRenderColor( ent, 255, 255, 255, 128 );
	SetEntityRenderFx( ent, RENDERFX_STROBE_FAST );
	DispatchKeyValue( ent, "targetname", "RXG_PUMPKIN" );
	DispatchSpawn( ent );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	SDKHook( ent, SDKHook_OnTakeDamage, OnPumpkinHit );
	g_pumpkin_taking_damage[ent] = false;
	g_pumpkin_spawn_time[ent] = GetGameTime();
	g_pumpkin_userid[ent] = userid;
	g_client_pumpkins[client]++;
	
	EmitSoundToAll( PUMPKIN_PLANT_SOUND, ent );
	if( c_arm_delay != 0.0 ) {
		CreateTimer( c_arm_delay * 2 / 3, Timer_PumpkinFlashFaster, EntIndexToEntRef(ent) );
	}
	CreateTimer( c_arm_delay, Timer_ArmPumpkin, EntIndexToEntRef(ent) );
	
	decl String:team_color[7];
	new TFTeam:client_team = TFTeam:GetClientTeam(client);
	
	if( client_team == TFTeam_Red ){
		team_color = "ff3d3d";
	} else if ( client_team == TFTeam_Blue ){
		team_color = "84d8f4";
	} else {
		team_color = "874fad";
	}
	
	decl String:player_name[32];
	GetClientName(client, player_name, sizeof player_name);
	
	//Throttle broadcasts
	new Float:time = GetGameTime();
	if( time >= g_last_broadcast[client] + c_broadcast_cooldown ) {
		PrintToChatAll( "\x07%s%s \x07FFD800is planting \x07FF6600Pumpkin Bombs!", team_color, player_name );
		g_last_broadcast[client] = time;
	}
	
	return true;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_PumpkinFlashFaster( Handle:timer, any:pumpkin ) {
	if( IsValidEntity(pumpkin) ) {
		SetEntityRenderFx( pumpkin, RENDERFX_STROBE_FASTER );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:Timer_ArmPumpkin( Handle:timer, any:pumpkin ) {
	if( IsValidEntity(pumpkin) ) {
		if( c_arm_solid ) {
			SetEntProp( pumpkin, Prop_Send, "m_CollisionGroup", 0 );
		}
		SetEntityRenderColor( pumpkin, 255, 255, 255, 255 );
		SetEntityRenderFx( pumpkin, RENDERFX_NONE );
		EmitSoundToAll( PUMPKIN_ARM_SOUND, pumpkin );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:OnPumpkinHit( pumpkin, &attacker, &inflictor, &Float:damage, &damagetype ) {
	
	if( g_pumpkin_taking_damage[pumpkin] ) return Plugin_Continue;
	
	if( GetGameTime() < g_pumpkin_spawn_time[pumpkin] + c_arm_delay ) {
		return Plugin_Handled;
	}
	
	g_pumpkin_taking_damage[pumpkin] = true;
	
	new userid = g_pumpkin_userid[pumpkin];
	new client = GetClientOfUserId(userid);
	
	//Attribute damage to pumpkin owner if still in server
	if( client != 0 ) {
		attacker = client;
		g_client_pumpkins[client]--;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}

//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
public RXGSTORE_OnUse( client ) {
	if( !IsPlayerAlive(client) ) return false;
	return SpawnPumpkin(client);
}
