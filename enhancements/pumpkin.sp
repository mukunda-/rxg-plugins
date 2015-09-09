#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
//#pragma newdecls required

public Plugin myinfo = 
{
	name = "Pumpkin",
	author = "Roker",
	description = "Pumpkin Library spawner idk",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define PUMPKIN_PLANT_SOUND "items/pumpkin_drop.wav"
#define PUMPKIN_ARM_SOUND "misc/doomsday_warhead.wav"


Handle sm_pumpkins_arm_delay;
Handle sm_pumpkins_arm_solid;

float c_arm_delay;
bool c_arm_solid;

#define MAXENTITIES 2048

int g_pumpkin_userid[MAXENTITIES];
bool g_pumpkin_taking_damage[MAXENTITIES];
float g_pumpkin_spawn_time[MAXENTITIES];

int g_client_userid[MAXPLAYERS+1];
int g_client_pumpkins[MAXPLAYERS+1];

//-------------------------------------------------------------------------------------------------
RecacheConvars() {
	c_arm_delay = GetConVarFloat( sm_pumpkins_arm_delay );
	c_arm_solid = GetConVarBool( sm_pumpkins_arm_solid );
}

//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] intval ) {
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
public OnPluginStart() {
	
	sm_pumpkins_arm_delay = CreateConVar( "sm_pumpkins_arm_delay", "0.9", "Time in seconds required for a Pumpkin Bomb to arm after being planted.", FCVAR_PLUGIN, true, 0.0, true, 5.0 );
	sm_pumpkins_arm_solid = CreateConVar( "sm_pumpkins_arm_solid", "1", "Whether Pumpkin Bombs should become solid when armed.", FCVAR_PLUGIN );
	
	HookConVarChange( sm_pumpkins_arm_delay, OnConVarChanged );
	HookConVarChange( sm_pumpkins_arm_solid, OnConVarChanged );
	RecacheConvars();
	
	RegAdminCmd( "sm_spawnpumpkin", Command_spawnpumpkin, ADMFLAG_RCON );
	HookEvent( "teamplay_round_start", Event_RoundStart );
}
//-------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max) {
	//CreateNative( "PMKN_SpawnPumpkin", Native_SpawnPumpkin );
	CreateNative( "PMKN_SpawnPumpkinAtAim", Native_SpawnPumpkinAtAim );
	RegPluginLibrary("pumpkin");
}
//-------------------------------------------------------------------------------------------------
public OnMapStart() {
	PrecacheSound( PUMPKIN_PLANT_SOUND );
	PrecacheSound( PUMPKIN_ARM_SOUND );
}

//-------------------------------------------------------------------------------------------------
public Event_RoundStart( Handle event, const char[] name, bool dontBroadcast ) {
	for( int i = 1; i <= MaxClients; i++ ) {
		g_client_pumpkins[i] = 0;
	}
}
//-------------------------------------------------------------------------------------------------
/*public Native_SpawnPumpkin( Handle plugin, numParams ) {
	float end[3];
	int client = GetNativeCell(1);
	end[0] = GetNativeCell(2);
	end[1] = GetNativeCell(3);
	end[2] = GetNativeCell(4);
	SpawnPumpkin(client, end, 0.0);
}*/
//-------------------------------------------------------------------------------------------------
public Action Command_spawnpumpkin( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnPumpkinAtAim(client, 0.0, 0);
	return Plugin_Handled;
}
//-------------------------------------------------------------------------------------------------
public bool Native_SpawnPumpkinAtAim(Handle plugin, numParams){
	int client = GetNativeCell(1);
	float maxDistance = GetNativeCell(2);
	int maxPumpkins = GetNativeCell(3);
	return SpawnPumpkinAtAim(client, maxDistance, maxPumpkins);
}
bool SpawnPumpkinAtAim(int client, float maxDistance, int maxPumpkins){
	float start[3];
	float angle[3];
	float end[3];
	float feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		float norm[3]; 
		float norm_angles[3];
		
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		float distance = GetVectorDistance( feet, end, true );

		if ( maxDistance != 0 && distance > maxDistance * maxDistance ) {
			PrintToChat( client, "\x07FFD800Cannot plant that far away." );
			return false;
		}
		
		if ( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot plant there." );
			return false;
		}
		SpawnPumpkin(client, end, maxPumpkins);
		return true;
	}
	return false;
}
//-------------------------------------------------------------------------------------------------
void SpawnPumpkin(int client, float end[3], int maxPumpkins){
	int userid = GetClientUserId(client);
	
	if( g_client_userid[client] != userid ) {
	
		//Client index changed hands
		g_client_userid[client] = userid;
		g_client_pumpkins[client] = 0;
		
	} else if( maxPumpkins != 0 && g_client_pumpkins[client] >= maxPumpkins ) {
	
		PrintToChat( client, "\x07FFD800You may not have more than \x073EFF3E%i \x07FF6600Pumpkins \x07FFD800planted at once.", maxPumpkins );
		return;
	}
	
	int ent = CreateEntityByName( "tf_pumpkin_bomb" );
	
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
}
//-------------------------------------------------------------------------------------------------
public Action OnPumpkinHit( pumpkin, &attacker, &inflictor, float &damage, &damagetype ) {
	
	if( g_pumpkin_taking_damage[pumpkin] ) return Plugin_Continue;
	
	if( GetGameTime() < g_pumpkin_spawn_time[pumpkin] + c_arm_delay ) {
		return Plugin_Handled;
	}
	
	g_pumpkin_taking_damage[pumpkin] = true;
	
	int userid = g_pumpkin_userid[pumpkin];
	int client = GetClientOfUserId(userid);
	
	//Attribute damage to pumpkin owner if still in server
	if( client != 0 ) {
		attacker = client;
		g_client_pumpkins[client]--;
		return Plugin_Changed;
	}
	
	return Plugin_Continue;
}
//-------------------------------------------------------------------------------------------------
public Action Timer_PumpkinFlashFaster( Handle timer, any pumpkin ) {
	if( IsValidEntity(pumpkin) ) {
		SetEntityRenderFx( pumpkin, RENDERFX_STROBE_FASTER );
	}
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public Action Timer_ArmPumpkin( Handle timer, any pumpkin ) {
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
public bool TraceFilter_All( entity, contentsMask ) {
	return false;
}


