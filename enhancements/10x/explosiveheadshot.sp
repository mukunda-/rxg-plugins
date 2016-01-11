
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>
#include <sdkhooks>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Explosive Headshot",
	author = "Roker",
	description = "Creates explosions on headshot.",
	version = "1.3.0",
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
	
	for(int client=1;client<=MaxClients;client++){
		if(!IsValidClient(client)) continue;
		SDKHook(client, SDKHook_OnTakeDamage, Event_Damage);
	}
	
	RecacheConvars();
}

//-----------------------------------------------------------------------------
public void OnClientPutInServer(int client){
	if(!IsValidClient(client)) return;
	SDKHook(client, SDKHook_OnTakeDamage, Event_Damage);
}

//-----------------------------------------------------------------------------
public Action Event_Damage(int victim, int &attacker, int &inflictor, float &damage, int &damageType, int &weapon, float damageForce[3], float damagePosition[3], int damagecustom){
	if(!IsValidClient(attacker)) return Plugin_Continue;
	if(victim == attacker) return Plugin_Continue;
	int index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );

	if(index != WEAPON_INDEX) return Plugin_Continue;
	if(damageType == DMG_BULLET) return Plugin_Continue; //HEADSHOT CHECK, IDK WHY BUT THIS WORKS
	if(!TF2_IsPlayerInCondition(victim, TFCond_BlastJumping)) return Plugin_Continue;
	
	
	int health = GetClientHealth(victim);
	if(damage*3 < health){
		damage = health/3.0;
	}
	
	spawnConfetti(victim);
	createExplosionTimer(victim, attacker);
	return Plugin_Changed;
}
void spawnConfetti(int victim){
	int ent = CreateEntityByName("info_particle_system");	
	DispatchKeyValue(ent, "effect_name", "bday_confetti");
	
	float pos[3];
	GetClientAbsOrigin(victim, pos);
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	DispatchSpawn(ent);
	
	ActivateEntity(ent);
	AcceptEntityInput(ent, "start");
	
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
public OnConVarChanged( Handle cvar, const char[] oldval, const char[] intval ) {
	RecacheConvars();
}
//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	
	int victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	int attacker = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	
	if( !IsValidClient(attacker) || !IsPlayerAlive(attacker) ) {
		return Plugin_Continue;
	}

	int weapon = GetPlayerWeaponSlot( attacker, TFWeaponSlot_Primary );
	if( !IsValidEntity(weapon) ) {
		return Plugin_Continue;
	}
	
	char weapon_classname[64];
	GetEntityClassname( weapon, weapon_classname, sizeof weapon_classname );
	
	// must be a client weapon, not an eyeball boss or something
	if( strncmp( weapon_classname, "tf_weapon", 9, false ) != 0 ) {
		return Plugin_Continue;
	}

	int index = GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" );
	
	bool isHeadshot = GetEventInt( event, "customkill" ) == TF_CUSTOM_HEADSHOT;
	
	if( !isHeadshot || index != WEAPON_INDEX ) {
		return Plugin_Continue;
	}
	
	createExplosionTimer(victim, attacker);
	return Plugin_Continue;
}

void createExplosionTimer(int victim, int attacker){
	Handle data;
	CreateDataTimer( 0.0, Timer_createExplosion, data);
	
	float location[3];
	GetClientEyePosition(victim,location);
	WritePackCell(data, attacker);
	WritePackFloat(data, location[0]);
	WritePackFloat(data, location[1]);
	WritePackFloat(data, location[2]);
}
//-----------------------------------------------------------------------------
public Action Timer_createExplosion(Handle timer, Handle data){

	ResetPack(data);
	int attacker = ReadPackCell(data);
	
	if( attacker == 0 ) {
		// invalid client
		return Plugin_Handled;
	}
	
	float location[3];
	location[0]  = ReadPackFloat(data);
	location[1]  = ReadPackFloat(data);
	location[2]  = ReadPackFloat(data);
	
	EmitAmbientSound("ambient/explosions/explode_8.wav", location, SOUND_FROM_WORLD, SNDLEVEL_NORMAL);
	
	int ent = CreateEntityByName("env_explosion");	 
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", attacker );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",c_damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",c_radius); 
	
	TeleportEntity(ent, location, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	
	return Plugin_Handled;
}