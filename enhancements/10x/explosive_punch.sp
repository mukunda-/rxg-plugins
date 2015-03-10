#pragma semicolon 1

#include <sourcemod>
#include <freak_fortress_2>
#include <freak_fortress_2_subplugin>


new bool:punchReady = false;
new boss = -1;

public Plugin:myinfo = {
	name = "Freak Fortress 2: Explosive Punch",
	author = "Roker",
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	
	return APLRes_Success;
}

public OnPluginStart2()
{
	LoadTranslations("freak_fortress_2.phrases");
	HookEvent( "player_hurt", Event_Player_Hurt);
}

public Action:FF2_OnAbility2(client,const String:plugin_name[],const String:ability_name[],action)
{
	if (!strcmp(ability_name,"explosive_punch")){
		boss=GetClientOfUserId(FF2_GetBossUserId(client));
		punchReady = true;
	}
	return Plugin_Continue;
}		
//-----------------------------------------------------------------------------
public OnMapStart(){
	PrecacheSound("ambient/explosions/explode_8.wav", true);
}
//-----------------------------------------------------------------------------
public Action:Event_Player_Hurt( Handle:event, const String:name[], bool:dontBroadcast ) {
	new attacker_id = GetEventInt( event, "attacker" );
	new attacker = GetClientOfUserId( attacker_id );
	new victim = GetClientOfUserId( GetEventInt( event, "userid" ));
	if(punchReady && boss == attacker){
		new Handle:data;
		CreateDataTimer( 0.0, Timer_createExplosion, data);
		decl Float:location[3];
		GetClientEyePosition(victim,location);
		WritePackCell(data, attacker_id);
		WritePackFloat(data, location[0]);
		WritePackFloat(data, location[1]);
		WritePackFloat(data, location[2]);
		punchReady = false;
	}
}
//-----------------------------------------------------------------------------
public Action:Timer_createExplosion(Handle:timer, Handle:data){

	ResetPack(data);
	new attacker = GetClientOfUserId( ReadPackCell(data) );
	
	if( attacker == 0 ) {
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
	
	new ent = CreateEntityByName("env_explosion");	 
	
	SetEntPropEnt( ent, Prop_Data, "m_hOwnerEntity", attacker );
	DispatchSpawn(ent);
	ActivateEntity(ent);
	new Float:damage=FF2_GetAbilityArgumentFloat(attacker, this_plugin_name, "explosive_punch", 0, 500.0);
	new Float:radius=FF2_GetAbilityArgumentFloat(attacker, this_plugin_name, "explosive_punch", 1, 400.0);
	SetEntProp(ent, Prop_Data, "m_iMagnitude", RoundToNearest(damage)); 
	SetEntProp(ent, Prop_Data, "m_iRadiusOverride", RoundToNearest(radius)); 
	
	TeleportEntity(ent, location, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(ent, "explode");
	AcceptEntityInput(ent, "kill");
	boss = -1;
	return Plugin_Handled;
}