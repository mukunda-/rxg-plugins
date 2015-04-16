
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Explosive Headshot",
	author = "Roker",
	description = "Creates explosions on headshot.",
	version = "1.2.1",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 402

Handle sm_explosiveheadshot_damage;
Handle sm_explosiveheadshot_radius;

int c_radius;
int c_damage;


//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", Event_Player_Death, EventHookMode_Post);
	sm_explosiveheadshot_radius = CreateConVar( "sm_explosiveheadshot_radius", "100", "Radius of explosive headshots.", FCVAR_PLUGIN );
	sm_explosiveheadshot_damage = CreateConVar( "sm_explosiveheadshot_damage", "100", "Damage of explosive headshots.", FCVAR_PLUGIN );
	
	HookConVarChange( sm_explosiveheadshot_radius, OnConVarChanged );
	HookConVarChange( sm_explosiveheadshot_damage, OnConVarChanged );
	
	RecacheConvars();
}
//-----------------------------------------------------------------------------
public OnMapStart(){
	PrecacheSound("ambient/explosions/explode_8.wav", true);
}
//-----------------------------------------------------------------------------
RecacheConvars() {
	c_radius = GetConVarInt( sm_explosiveheadshot_radius );
	c_damage = GetConVarInt( sm_explosiveheadshot_damage );
}
//-----------------------------------------------------------------------------
public OnConVarChanged( Handle cvar, const String:oldval[], const String:intval[] ) {
	RecacheConvars();
}
//-----------------------------------------------------------------------------
public Action:Event_Player_Death( Handle event, const String:name[], bool dontBroadcast ) {
	
	int victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	int shooter_id = GetEventInt( event, "attacker" );
	int shooter = GetClientOfUserId( shooter_id );
	
	if( !IsValidClient(shooter) || !IsPlayerAlive(shooter) ) {
		return Plugin_Continue;
	}

	int weapon = GetPlayerWeaponSlot( shooter, TFWeaponSlot_Primary );
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	bool isHeadshot = GetEventInt( event, "customkill" ) == TF_CUSTOM_HEADSHOT;
	
	if( !isHeadshot || index != WEAPON_INDEX ) {
		return Plugin_Continue;
	}
	
	Handle data;
	CreateDataTimer( 0.0, Timer_createExplosion, data);
	
	float location[3];
	GetClientEyePosition(victim,location);
	WritePackCell(data, shooter_id);
	WritePackFloat(data, location[0]);
	WritePackFloat(data, location[1]);
	WritePackFloat(data, location[2]);
	
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action:Timer_createExplosion(Handle:timer, Handle:data){

	ResetPack(data);
	int shooter_index = GetClientOfUserId( ReadPackCell(data) );
	
	if( shooter_index == 0 ) {
		// invalid client
		CloseHandle(data);
		return Plugin_Handled;
	}
	
	decl Float:location[3];
	location[0]  = ReadPackFloat(data);
	location[1]  = ReadPackFloat(data);
	location[2]  = ReadPackFloat(data);
	CloseHandle(data);
	
	EmitAmbientSound("ambient/explosions/explode_8.wav", location, SOUND_FROM_WORLD, SNDLEVEL_NORMAL);
	
	int ent = CreateEntityByName("env_explosion");	 
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", shooter_index );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",c_damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",c_radius); 
	
	TeleportEntity(ent, location, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	
	return Plugin_Handled;
}