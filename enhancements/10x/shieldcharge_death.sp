
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin myinfo = {
	name = "ShieldCharge Death",
	author = "Roker",
	description = "Creates explosions when shield-charging demos collide.",
	version = "1.2.2",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 406
#define PLAYER_WIDTH 15.0

//-----------------------------------------------------------------------------
public OnPluginStart() {
	HookEvent( "player_death", Event_Player_Death, EventHookMode_Post);
}

//-----------------------------------------------------------------------------
public OnMapStart() {
	PrecacheSound("ambient/explosions/explode_8.wav", true);
}

//-----------------------------------------------------------------------------
public Action Event_Player_Death( Handle event, const char[] name, bool dontBroadcast ) {
	
	int attacker_id = GetEventInt( event, "attacker" );
	int attacker = GetClientOfUserId( attacker_id );
	int victim_id = GetEventInt( event, "userid" );
	int victim = GetClientOfUserId( victim_id );
	
	
	if( !IsValidClient(attacker) || !IsPlayerAlive(attacker) ) {
		return Plugin_Continue;
	}
	
	bool isBash = GetEventInt( event, "customkill" ) == TF_CUSTOM_CHARGE_IMPACT;
	
	if( !isBash || !hasCorrectWeapon(attacker) || !hasCorrectWeapon(victim) ||
			!TF2_IsPlayerInCondition(victim, TFCond_Charging) ) {
		
		return Plugin_Continue;
	}
	
	Handle data;
	CreateDataTimer( 0.1, Timer_createExplosion, data);
	
	WritePackCell(data, attacker_id);
	WritePackCell(data, victim_id);
	
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
public Action Timer_createExplosion(Handle timer, Handle data){
	
	ResetPack(data);
	int attacker = GetClientOfUserId( ReadPackCell(data) );
	int victim = GetClientOfUserId( ReadPackCell(data) );
	
	if( victim == 0 || attacker == 0 ) {
		// invalid client
		return Plugin_Handled;
	}
	
	createExplosion(victim);
	createExplosion(attacker);

	return Plugin_Handled;
}

//-----------------------------------------------------------------------------
void createExplosion(int client) {
	float pos[3];
	GetClientEyePosition(client,pos);
	EmitAmbientSound("ambient/explosions/explode_8.wav", pos, SOUND_FROM_WORLD, SNDLEVEL_NORMAL);
	
	int ent = CreateEntityByName("env_explosion");	 
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", client );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	int magnitude = 300;
	int radius = 150;
	
	SetEntProp(ent, Prop_Data, "m_iMagnitude", magnitude); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride", radius); 
	
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
}

//-----------------------------------------------------------------------------
public void TF2_OnConditionRemoved(int client, TFCond condition) 
{ 
    if (condition == TFCond_Charging) {

		//not correct weapon
		if( !hasCorrectWeapon(client) ) return;
		
		float start[3]; float angle[3]; float end[3];
		
		float minimums[3] = { -PLAYER_WIDTH, -PLAYER_WIDTH, 10.0 };
		float maximums[3] = { PLAYER_WIDTH, PLAYER_WIDTH, 68.0 };
		
		GetClientAbsOrigin( client, start );
		GetClientAbsAngles( client, angle );
		GetAngleVectors(angle,end,NULL_VECTOR,NULL_VECTOR);
		ScaleVector(end,500.0);
		AddVectors(start,end,end);
		
		TR_TraceHullFilter( start, end, minimums, maximums, CONTENTS_SOLID , TraceFilter_All);
		
		if( TR_DidHit() ) {
			TR_GetEndPosition( end );
			float distance = GetVectorDistance( start, end, true );
			
			if(distance < 500){
				ForcePlayerSuicide(client);
			}
		}
	}
}

//-------------------------------------------------------------------------------------------------
public bool TraceFilter_All( entity, contentsMask ) {
	return false;
}

//-------------------------------------------------------------------------------------------------
bool hasCorrectWeapon(int client)
{
	int shield = FindDemoShield(client);
	int index = ( IsValidEntity(shield) ? GetEntProp( shield, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
	return (index == WEAPON_INDEX);
}

//-------------------------------------------------------------------------------------------------
stock FindDemoShield(int iClient)
{
	//int index = ( IsValidEntity(shield) ? GetEntProp( shield, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
    int iEnt = MaxClients + 1; while ((iEnt = FindEntityByClassname2(iEnt, "tf_wearable_demoshield")) != -1)
    {
        if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEnt, Prop_Send, "m_bDisguiseWearable"))
        {
            return iEnt;
        }
    }
    return -1;
}

//-------------------------------------------------------------------------------------------------
stock int FindEntityByClassname2(startEnt, const String:classname[])
{
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
    return FindEntityByClassname(startEnt, classname);
}

