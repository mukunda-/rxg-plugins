 
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <rxgstore>

#pragma semicolon 1

//-------------------------------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "pumpkin item",
	author = "WhiteThunder",
	description = "spawnable pumpkin bombs",
	version = "2.1.4",
	url = "www.reflex-gamers.com"
};

#define PUMPKIN_PLANT_SOUND "items/pumpkin_drop.wav"
#define PUMPKIN_ARM_SOUND "misc/doomsday_warhead.wav"

#define MIN_DISTANCE 50.0
#define MAX_DISTANCE 750.0
#define MAXENTITIES 2048

#define BROADCAST_COOLDOWN 15.0
#define MAX_PUMPKINS_PER_PLAYER 10
#define ACTIVATION_DELAY 0.9

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
public OnPluginStart() {
	RXGSTORE_RegisterItem( ITEM_NAME, ITEMID, ITEM_FULLNAME );
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
		g_last_broadcast[i] = -BROADCAST_COOLDOWN;
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
	} else if( g_client_pumpkins[client] >= MAX_PUMPKINS_PER_PLAYER ) {
		PrintToChat( client, "\x07FFD800You may not have more than \x073EFF3E%i \x07FF6600Pumpkins \x07FFD800planted at once.", MAX_PUMPKINS_PER_PLAYER );
		RXGSTORE_ShowUseItemMenu(client);
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

		if ( distance > MAX_DISTANCE * MAX_DISTANCE ) {
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
	CreateTimer( ACTIVATION_DELAY * 2 / 3, Timer_PumpkinFlashFaster, EntIndexToEntRef(ent) );
	CreateTimer( ACTIVATION_DELAY, Timer_ArmPumpkin, EntIndexToEntRef(ent) );
	
	decl String:team_color[7];
	new team = GetClientTeam(client);
	
	if( team == 2 ){
		team_color = "ff3d3d";
	} else if ( team == 3 ){
		team_color = "84d8f4";
	} else {
		return true;
	}
	
	decl String:name[32];
	GetClientName(client, name, sizeof name);
	
	//Throttle broadcasts
	new Float:time = GetGameTime();
	if( time >= g_last_broadcast[client] + BROADCAST_COOLDOWN ) {
		PrintToChatAll( "\x07%s%s \x07FFD800is planting \x07FF6600Pumpkin Bombs!", team_color, name );
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
		SetEntProp( pumpkin, Prop_Send, "m_CollisionGroup", 0 );
		SetEntityRenderColor( pumpkin, 255, 255, 255, 255 );
		SetEntityRenderFx( pumpkin, RENDERFX_NONE );
		EmitSoundToAll( PUMPKIN_ARM_SOUND, pumpkin );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action:OnPumpkinHit( pumpkin, &attacker, &inflictor, &Float:damage, &damagetype ) {
	
	if( g_pumpkin_taking_damage[pumpkin] ) return Plugin_Continue;
	
	if( GetGameTime() < g_pumpkin_spawn_time[pumpkin] + ACTIVATION_DELAY ) {
		return Plugin_Handled;
	}
	
	g_pumpkin_taking_damage[pumpkin] = true;
	
	new userid = g_pumpkin_userid[pumpkin];
	new client = GetClientOfUserId(userid);
	
	//Damage is from owner
	attacker = client;
	
	//Client must be original user
	if( g_client_userid[client] == userid ) {
		g_client_pumpkins[client]--;
	}
	
	return Plugin_Changed;
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
