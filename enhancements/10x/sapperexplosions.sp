
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "Sapper Explosions",
	author = "Roker",
	description = "Creates explosions on when a sappers destroy buildings.",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 402

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "object_destroyed", Event_Object_Destroyed, EventHookMode_Pre);
}
//-----------------------------------------------------------------------------
public OnMapStart(){
	PrecacheSound("ambient/explosions/explode_8.wav", true);
}
//-----------------------------------------------------------------------------
public Action:Event_Object_Destroyed( Handle event, const String:name[], bool dontBroadcast ) {
	
	int client = GetClientOfUserId( GetEventInt( event, "attacker" ) );
	int building = GetEventInt(event, "index");
	char weaponName[32];
	
	GetEventString(event, "weapon", weaponName, sizeof(weaponName));
	if(!StrEqual(weaponName, "obj_attachment_sapper")){return Plugin_Continue;}
	
	Handle data;
	CreateDataTimer( 0.0, Timer_createExplosion, data);
	
	float location[3];
	GetEntPropVector(building, Prop_Send, "m_vecOrigin", location);
	
	WritePackCell(data, client);
	WritePackFloat(data, location[0]);
	WritePackFloat(data, location[1]);
	WritePackFloat(data, location[2]);
	
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
public Action:Timer_createExplosion(Handle:timer, Handle:data){

	ResetPack(data);
	int shooter = ReadPackCell(data);
	
	if( shooter == 0 ) {
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
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", shooter );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude", 100); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride", 100); 
	
	TeleportEntity(ent, location, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	
	return Plugin_Handled;
}