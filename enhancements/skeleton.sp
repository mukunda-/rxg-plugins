#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
//#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Skeleton",
	author = "Roker",
	description = "Spawnable Skeletons.",
	version = "1.0.1",
	url = "www.reflex-gamers.com"
};

Handle sm_skeleton_max_summon_distance;
Handle sm_skeletons_cooldown_period;
Handle sm_skeletons_broadcast_cooldown;

float c_max_summon_distance;
float c_cooldown_period;
float c_broadcast_cooldown;

float g_last_broadcast[MAXPLAYERS+1];
int g_client_userid[MAXPLAYERS+1];
int g_spawn_count[MAXPLAYERS+1];

bool timerExists = false;


public void OnPluginStart(){
	sm_skeleton_max_summon_distance = CreateConVar( "sm_skeleton_max_summon_distance", "750", "The maximum distance you may summon a Skeleton away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	sm_skeletons_cooldown_period = CreateConVar( "sm_skeletons_cooldown_period", "60", "How often users regain a skeleton spawn.", FCVAR_PLUGIN, true, 0.0 );
	sm_skeletons_broadcast_cooldown = CreateConVar( "sm_skeletons_broadcast_cooldown", "30", "How frequently to broadcast that a player is spawning skeletons.", FCVAR_PLUGIN, true, 0.0 );
	RegAdminCmd("sm_spawnskeleton", Command_SpawnSkeleton, ADMFLAG_RCON);
	RegAdminCmd("sm_slayskeletons", Command_SlaySkeletons, ADMFLAG_RCON);
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, err_max) {
	CreateNative( "SKEL_SpawnSkeleton", Native_SpawnSkeleton );
	RegPluginLibrary("skeleton");
}
//---------------------------------------------------------------------------------------	----------
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] newval) {
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
void RecacheConvars(){
	c_max_summon_distance = GetConVarFloat(sm_skeleton_max_summon_distance);
	c_cooldown_period = GetConVarFloat(sm_skeletons_cooldown_period);
	c_broadcast_cooldown = GetConVarFloat(sm_skeletons_broadcast_cooldown);
}
//-----------------------------------------------------------------------------
public OnMapStart() {
	// reset last broadcast time for all clients
	for( int i = 1; i <= MaxClients; i++ ) {
		g_last_broadcast[i] = -c_broadcast_cooldown;
	}
	
	for(int i=0;i<=7;i++){
		char sound[64];
		Format( sound, sizeof sound, "misc/halloween/skeletons/skelly_medium_0%i.wav", i );
		PrecacheSound(sound,true );
	}
}
//-----------------------------------------------------------------------------
public Action Timer_Lower_Count(Handle timer){
	bool active = false;
	for( new i = 1; i <= MaxClients; i++ ) {
		if(g_spawn_count[i] > 0){
			g_spawn_count[i]--;
			active = true;
		}
	}
	if(!active){
		timerExists = false;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}
//-------------------------------------------------------------------------------------------------
public Action Command_SpawnSkeleton( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	
	int team;
	if( args > 0 ) {
		char team_arg[12];
		GetCmdArg( 1, team_arg, sizeof team_arg );
		team = StringToInt(team_arg);
	} else {
		team = GetClientTeam(client);
	}
	
	SpawnSkeleton( client, team );
	return Plugin_Handled;
}
//-------------------------------------------------------------------------------------------------
public Action Command_SlaySkeletons( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SlaySkeletons( client );
	return Plugin_Handled;
}
//-------------------------------------------------------------------------------------------------
public Native_SpawnSkeleton( Handle plugin, numParams ) {
	int client = GetNativeCell(1);
	int team = GetNativeCell(2);
	return SpawnSkeleton(client, team);
}
//-------------------------------------------------------------------------------------------------
void SlaySkeletons(int client){
	int ent = -1;
	int prev;
	int count;
	while ((ent = FindEntityByClassname(ent, "tf_zombie")) != -1)
	{
		if (prev) RemoveEdict(prev);
		prev = ent;
		count++;
	}
	if (prev) RemoveEdict(prev);
	PrintToConsole(client,"%i skeletons slayed.",count);
}
//-------------------------------------------------------------------------------------------------
bool SpawnSkeleton(int client, team){
	if( !IsPlayerAlive(client) ){
		PrintToChat( client, "\x07FFD800Cannot summon when dead." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Cloaked ) ){
		PrintToChat( client, "\x07FFD800Cannot summon when cloaked." );
		return false;
	}
	if( TF2_IsPlayerInCondition(client, TFCond_Disguised ) ){
		PrintToChat( client, "\x07FFD800Cannot summon when disguised." );
		return false;
	}
	
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
		
		if( c_max_summon_distance != 0 && distance > c_max_summon_distance * c_max_summon_distance ) {
			PrintToChat( client, "\x07FFD800Cannot summon that far away." );
			return false;
		}
		
		if( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot summon there." );
			return false;
		}
		if(getSkeletonCount() >= 10){
			PrintToChat( client, "\x07FFD800Too many skeletons alive to summon more." );
			return false;
		}
		char map[64];
		GetCurrentMap(map, sizeof(map));
		Format(map, sizeof(map), "maps/%s.nav", map);
		if(!FileExists(map)){
			PrintToChat( client, "\x07FFD800This Map has not yet been prepped for skeletons. Contact an administrator to get this fixed." );
			return false;
		}
		//check if index is the same user
		int userid = GetClientUserId(client);
		if( g_client_userid[client] != userid ) {
			//Client index changed hands
			g_client_userid[client] = userid;
			g_spawn_count[client] = 0;
		}
		//check if they've spawned too many
		if(g_spawn_count[client] >= 10){
			PrintToChat( client, "\x07FFD800You have summoned too many skeletons recently." );
			return false;
		}
		//spawn restriction stuff
		g_spawn_count[client]++;
		if(!timerExists){
			CreateTimer(c_cooldown_period, Timer_Lower_Count, _, TIMER_REPEAT);
			timerExists = true;
		}
		
		char team_color[7];
		char player_name[64];
		GetClientName(client,player_name,sizeof(player_name));
		TFTeam client_team = TFTeam:GetClientTeam(client);
		
		if( client_team == TFTeam_Red ){
			team_color = "ff3d3d";
		} else if ( client_team == TFTeam_Blue ){
			team_color = "84d8f4";
		} else {
			team_color = "874fad";
		}
	
		float time = GetGameTime();
		if( time >= g_last_broadcast[client] + c_broadcast_cooldown ) {
			PrintToChatAll( "\x07%s%s \x07FFD800is summoning skeletons!", team_color, player_name );
			g_last_broadcast[client] = time;
		}
	}else{
		return false;
	}
	
	int ent = CreateEntityByName("tf_zombie");
	SetEntProp( ent, Prop_Data, "m_iTeamNum", team );
	if(team == GetClientTeam(client)){ //SKELETON DIES IF OWNER IS NOT THE SAME TEAM
		SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	}
	
	DispatchSpawn( ent );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
	
	int random = GetRandomInt(1,7);
	char sound[64];
	Format( sound, sizeof sound, "misc/halloween/skeletons/skelly_medium_0%i.wav", random );
	EmitAmbientSound(sound, end, SOUND_FROM_WORLD, SNDLEVEL_NORMAL);
	
	return true;
}
//-------------------------------------------------------------------------------------------------
int getSkeletonCount(){
	int ent = -1;
	int count;
	while ((ent = FindEntityByClassname(ent, "tf_zombie")) != -1)
	{
		count++;
	}
	return count;
}

//-------------------------------------------------------------------------------------------------
public bool TraceFilter_All( entity, contentsMask ) {
	return false;
}