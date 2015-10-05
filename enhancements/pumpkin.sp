#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = 
{
	name = "Pumpkin",
	author = "Roker",
	description = "Pumpkin Spawner Library",
	version = "1.1.1",
	url = "www.reflex-gamers.com"
};

#define PUMPKIN_PLANT_SOUND "items/pumpkin_drop.wav"
#define PUMPKIN_ARM_SOUND "misc/doomsday_warhead.wav"

Handle sm_pumpkins_max_per_player;
Handle sm_pumpkins_max_plant_distance;
Handle sm_pumpkins_arm_delay;
Handle sm_pumpkins_arm_solid;
Handle sm_pumpkins_broadcast_cooldown;

int c_max_per_player;
float c_max_plant_distance;
float c_arm_delay;
bool c_arm_solid;
float c_broadcast_cooldown;

#define MAXENTITIES 2048

int g_pumpkin_userid[MAXENTITIES];
bool g_pumpkin_taking_damage[MAXENTITIES];
float g_pumpkin_spawn_time[MAXENTITIES];
int g_skeleton_pumpkin[MAXENTITIES];

int g_client_userid[MAXPLAYERS+1];
int g_client_pumpkins[MAXPLAYERS+1];
float g_last_broadcast[MAXPLAYERS+1];

//-------------------------------------------------------------------------------------------------
void RecacheConvars() {
	c_max_per_player = GetConVarInt( sm_pumpkins_max_per_player );
	c_max_plant_distance = GetConVarFloat( sm_pumpkins_max_plant_distance );
	c_arm_delay = GetConVarFloat( sm_pumpkins_arm_delay );
	c_arm_solid = GetConVarBool( sm_pumpkins_arm_solid );
	c_broadcast_cooldown = GetConVarFloat( sm_pumpkins_broadcast_cooldown );
}

//-------------------------------------------------------------------------------------------------
public void OnConVarChanged( Handle cvar, const char[] oldval, const char[] intval ) {
	RecacheConvars();
}

//-------------------------------------------------------------------------------------------------
public void OnPluginStart() {
	sm_pumpkins_max_per_player = CreateConVar( "sm_pumpkins_max_per_player", "15", "Maximum number of Pumpkin Bombs allowed per player at once. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_max_plant_distance = CreateConVar( "sm_pumpkins_max_plant_distance", "500", "The maximum distance you may plant Pumpkin Bombs away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_pumpkins_arm_delay = CreateConVar( "sm_pumpkins_arm_delay", "0.9", "Time in seconds required for a Pumpkin Bomb to arm after being planted.", FCVAR_PLUGIN, true, 0.0, true, 5.0 );
	sm_pumpkins_arm_solid = CreateConVar( "sm_pumpkins_arm_solid", "1", "Whether Pumpkin Bombs should become solid when armed.", FCVAR_PLUGIN );
	sm_pumpkins_broadcast_cooldown = CreateConVar( "sm_pumpkins_broadcast_cooldown", "30", "How frequently to broadcast that a player is planing Pumpkin Bombs (per player).", FCVAR_PLUGIN, true, 0.0 );
	
	HookConVarChange( sm_pumpkins_arm_delay, OnConVarChanged );
	HookConVarChange( sm_pumpkins_arm_solid, OnConVarChanged );
	HookConVarChange( sm_pumpkins_max_per_player, OnConVarChanged );
	HookConVarChange( sm_pumpkins_max_plant_distance, OnConVarChanged );
	HookConVarChange( sm_pumpkins_broadcast_cooldown, OnConVarChanged );
	RecacheConvars();
	
	RegAdminCmd( "sm_spawnpumpkin", Command_spawnpumpkin, ADMFLAG_RCON );
	HookEvent( "teamplay_round_start", Event_RoundStart );
}

//-------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	CreateNative( "Pumpkin_SpawnPumpkin", Native_SpawnPumpkin );
	CreateNative( "Pumpkin_SpawnPumpkinAtAim", Native_SpawnPumpkinAtAim );
	RegPluginLibrary("pumpkin");
}

//-------------------------------------------------------------------------------------------------
public void OnMapStart() {
	PrecacheSound( PUMPKIN_PLANT_SOUND );
	PrecacheSound( PUMPKIN_ARM_SOUND );
	for( int i = 1; i <= MaxClients; i++ ) {
		g_last_broadcast[i] = -c_broadcast_cooldown;
	}
}

//-------------------------------------------------------------------------------------------------
public Action Event_RoundStart( Handle event, const char[] name, bool dontBroadcast ) {
	for( int i = 1; i <= MaxClients; i++ ) {
		g_client_pumpkins[i] = 0;
	}
}

//-------------------------------------------------------------------------------------------------
public Action Command_spawnpumpkin( int client, int args ) {
	if( client == 0 ) return Plugin_Continue;
	SpawnPumpkinAtAim(client);
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public int Native_SpawnPumpkin( Handle plugin, int numParams ) {
	int client = GetNativeCell(1);
	float end[3];
	GetNativeArray(2, end, 3);
	SpawnPumpkin(client, end);
}

//-------------------------------------------------------------------------------------------------
public int Native_SpawnPumpkinAtAim(Handle plugin, int numParams){
	int client = GetNativeCell(1);
	return SpawnPumpkinAtAim(client);
}

//-------------------------------------------------------------------------------------------------
bool SpawnPumpkinAtAim(int client){
	float start[3];
	float angle[3];
	float end[3];
	float feet[3];
	GetClientEyePosition( client, start );
	GetClientEyeAngles( client, angle );
	GetClientAbsOrigin( client, feet );
	
	TR_TraceRayFilter(start, angle, MASK_PLAYERSOLID, RayType_Infinite, TraceFilter_Self, client);
 	if(TR_DidHit() == true)
    {
        int ent = TR_GetEntityIndex();
        char classname[64];
        GetEntityClassname(ent, classname, sizeof(classname));
        if(StrEqual(classname, "tf_zombie")){
        	SkeletonAttach(ent);
        	return true;
        }
    }
	TR_TraceRayFilter( start, angle, CONTENTS_SOLID, RayType_Infinite, TraceFilter_All );

	if( TR_DidHit() ) {
		float norm[3]; 
		float norm_angles[3];
		
		TR_GetPlaneNormal( INVALID_HANDLE, norm );
		GetVectorAngles( norm, norm_angles );
		TR_GetEndPosition( end );

		float distance = GetVectorDistance( feet, end, true );

		if ( c_max_plant_distance != 0 && distance > c_max_plant_distance * c_max_plant_distance ) {
			PrintToChat( client, "\x07FFD800Cannot plant that far away." );
			return false;
		}
		
		if ( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot plant there." );
			return false;
		}
		return SpawnPumpkin(client, end);
	}
	return false;
}

//-------------------------------------------------------------------------------------------------
void SkeletonAttach(int skeleton){
	int pumpkin = NewPumpkin();
	g_skeleton_pumpkin[skeleton] = pumpkin;
	
	float skeletonPos[3];
	float skeletonAng[3];
	GetEntPropVector(skeleton, Prop_Data, "m_vecAbsOrigin", skeletonPos);
	GetEntPropVector(skeleton, Prop_Data, "m_angRotation", skeletonAng);
	
	skeletonPos[2] += 55.0;
	TeleportEntity( pumpkin, skeletonPos, skeletonAng, NULL_VECTOR );
	
	SetVariantString("!activator");
	AcceptEntityInput( pumpkin, "SetParent", skeleton );
}

//-------------------------------------------------------------------------------------------------
public void OnEntityDestroyed(int skeleton){
	if(skeleton <= MaxClients){return;}
	
	char classname[64];
	GetEntityClassname(skeleton, classname, sizeof(classname)); 						//classname of destroyed entity
	if(!StrEqual(classname, "tf_zombie")) { return;}									//is destroyed entity a skeleton?
	if(!IsValidEntity(g_skeleton_pumpkin[skeleton])) { return;}							//does the skeleton have a pumpkin?
	GetEntityClassname(g_skeleton_pumpkin[skeleton], classname, sizeof(classname));		//classname of "pumpkin"
	if(!StrEqual(classname, "tf_pumpkin_bomb")) { return;}								//is it actually a pumpkin
	int attacker = GetClientOfUserId(g_pumpkin_userid[g_skeleton_pumpkin[skeleton]]);
	SDKHooks_TakeDamage(g_skeleton_pumpkin[skeleton], attacker, 0, 100.0);				//make pumpkin explode
}

//-------------------------------------------------------------------------------------------------
bool SpawnPumpkin(int client, float end[3]){
	int userid = GetClientUserId(client);
	if( g_client_userid[client] != userid ) {
		//Client index changed hands
		g_client_userid[client] = userid;
		g_client_pumpkins[client] = 0;
	}else if( c_max_per_player != 0 && g_client_pumpkins[client] >= c_max_per_player ) {
		PrintToChat( client, "\x07FFD800You may not have more than \x073EFF3E%i \x07FF6600Pumpkins \x07FFD800planted at once.", c_max_per_player );
		return false;
	}
	
	//CHECKS
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
	
	char team_color[7];
	TFTeam client_team = view_as<TFTeam>GetClientTeam(client);
	
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
	
	int ent = NewPumpkin();
	
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	SetEntityRenderColor( ent, 255, 255, 255, 128 );
	SetEntityRenderFx( ent, RENDERFX_STROBE_FAST );
	DispatchKeyValue( ent, "targetname", "RXG_PUMPKIN" );
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
	return true;
}

//-------------------------------------------------------------------------------------------------
int NewPumpkin(){
	int ent = CreateEntityByName( "tf_pumpkin_bomb" );
	DispatchSpawn( ent );
	return ent;
}

//-------------------------------------------------------------------------------------------------
public Action OnPumpkinHit( int pumpkin, int &attacker, int &inflictor, float &damage, int &damagetype ) {
	
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
public bool TraceFilter_All( int entity, int contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
public bool TraceFilter_Self(int entity, int mask, any data)
{
    if(entity == data)
        return false;
    return true;
}  