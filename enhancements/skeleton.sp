#include <sourcemod>
#include <sdktools>
#include <rxgstore>

#pragma semicolon 1
//#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Skeleton",
	author = "Roker",
	description = "Spawnable Skeletons.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

Handle sm_skeleton_max_summon_distance;

float c_max_summon_distance;

public void OnPluginStart(){
	sm_skeleton_max_summon_distance = CreateConVar( "sm_skeleton_max_summon_distance", "750", "The maximum distance you may summon a Skeleton away from yourself. Set to 0 for no limit.", FCVAR_PLUGIN, true, 0.0 );
	RegAdminCmd("sm_spawnskeleton", Command_SpawnSkeleton, ADMFLAG_RCON);
	RegAdminCmd("sm_slayskeletons", Command_SlaySkeletons, ADMFLAG_RCON);
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}
//-------------------------------------------------------------------------------------------------
void RecacheConvars(){
	c_max_summon_distance = GetConVarFloat(sm_skeleton_max_summon_distance);
}
//-------------------------------------------------------------------------------------------------
public Action:Command_SpawnSkeleton( client, args ) {
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
public Action:Command_SlaySkeletons( client, args ) {
	if( client == 0 ) return Plugin_Continue;
	SlaySkeletons( client );
	return Plugin_Handled;
}
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
			//RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		
		if( FloatAbs( norm_angles[0] - (270.0) ) > 45.0 ) {
			PrintToChat( client, "\x07FFD800Cannot summon there." );
			//RXGSTORE_ShowUseItemMenu(client);
			return false;
		}
		if(getSkeletonCount() >= 10){
			PrintToChat( client, "\x07FFD800Too many skeletons alive to summon more." );
			return false;
		}
	}
	
	new ent = CreateEntityByName("tf_zombie");
	SetEntProp( ent, Prop_Data, "m_iTeamNum", team );
	if(team == GetClientTeam(client)){ //SKELETON DIES IF OWNER IS NOT THE SAME TEAM
		SetEntPropEnt( ent, Prop_Send, "m_hOwnerEntity", client );
	}
	
	DispatchSpawn( ent );
	SetEntProp( ent, Prop_Send, "m_CollisionGroup", 2 );
	TeleportEntity( ent, end, NULL_VECTOR, NULL_VECTOR );
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