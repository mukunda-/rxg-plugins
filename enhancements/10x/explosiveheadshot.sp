
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "Explosive Headshot",
	author = "Roker",
	description = "Creates explosions on headshot.",
	version = "1.1.0",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 402

new Handle:sm_explosiveheadshot_damage;
new Handle:sm_explosiveheadshot_radius;

new c_radius;
new c_damage;

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", Event_Player_Death );
	sm_explosiveheadshot_radius = CreateConVar( "sm_explosiveheadshot_radius", "100", "Radius of explosive headshots.", FCVAR_PLUGIN );
	sm_explosiveheadshot_damage = CreateConVar( "sm_explosiveheadshot_damage", "100", "Damage of explosive headshots.", FCVAR_PLUGIN );
	
	HookConVarChange( sm_explosiveheadshot_radius, OnConVarChanged );
	HookConVarChange( sm_explosiveheadshot_damage, OnConVarChanged );
	
	RecacheConvars();
}
//-----------------------------------------------------------------------------
public OnMapStart(){
	PrecacheSound("ambient/explosions/explode_8.wav", true);
	g_ExplosionSprite = PrecacheModel("sprites/sprite_fire01.vmt");
}
//-----------------------------------------------------------------------------
RecacheConvars() {
	c_radius = GetConVarInt( sm_explosiveheadshot_radius );
	c_damage = GetConVarInt( sm_explosiveheadshot_damage );
}

//-----------------------------------------------------------------------------
public OnConVarChanged( Handle:cvar, const String:oldval[], const String:newval[] ) {
	RecacheConvars();
}
//-----------------------------------------------------------------------------
public Action:Event_Player_Death( Handle:event, const String:name[], bool:dontBroadcast ) {
	
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ) );
	new shooter = GetClientOfUserId( GetEventInt( event, "attacker" ) );

	new weapon = GetPlayerWeaponSlot( shooter, TFWeaponSlot_Primary );
	new index = ( IsValidEntity(weapon) ? GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	
	new bool:isHeadshot = GetEventInt(event, "customkill") == TF_CUSTOM_HEADSHOT;
	 
	if( index != WEAPON_INDEX ) {
		return Plugin_Continue;
	}
	if( !isHeadshot ) {
		return Plugin_Continue;
	}
		
	createExplosion(victim,shooter);
	
	return Plugin_Continue;
}
//-----------------------------------------------------------------------------
createExplosion(victim,shooter){
	decl Float:location[3];
	GetClientEyePosition(victim,location);
	EmitAmbientSound("ambient/explosions/explode_8.wav", location, SOUND_FROM_WORLD, SNDLEVEL_NORMAL);
	
	new ent = CreateEntityByName("env_explosion");	 
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", shooter );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	SetEntProp(ent, Prop_Data, "m_iMagnitude",c_damage); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride",c_radius); 
	
	TeleportEntity(ent, location, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}
