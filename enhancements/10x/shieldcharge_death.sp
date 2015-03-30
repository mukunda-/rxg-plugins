
#include <sourcemod>
#include <sdktools>
#include <tf2_stocks>
#include <rxgcommon>

#pragma semicolon 1

//-----------------------------------------------------------------------------
public Plugin:myinfo = {
	name = "ShieldCharge Death",
	author = "Roker",
	description = "Creates explosions on headshot.",
	version = "1.2.1",
	url = "www.reflex-gamers.com"
};

#define WEAPON_INDEX 406

//-----------------------------------------------------------------------------
public TF2_OnConditionRemoved(client, TFCond:condition) 
{ 
    if (condition == TFCond_Charging){	

		//not correct weapon
		new shield = FindDemoShield(client);
		new index = ( IsValidEntity(shield) ? GetEntProp( shield, Prop_Send, "m_iItemDefinitionIndex" ) : -1 );
		
		if(index != WEAPON_INDEX){
			return;
		}
		
		decl Float:start[3], Float:angle[3], Float:end[3], Float:minimums[3], Float:maximums[3];
		minimums = {-10.0,-10.0,10.0};
		maximums = {10.0,10.0,68.0};
		GetClientAbsOrigin( client, start );
		GetClientAbsAngles( client, angle );
		GetAngleVectors(angle,end,NULL_VECTOR,NULL_VECTOR);
		ScaleVector(end,500.0);
		AddVectors(start,end,end);
		
		TR_TraceHullFilter( start, end, minimums, maximums, CONTENTS_SOLID , TraceFilter_All);
		if( TR_DidHit() ) {
			TR_GetEndPosition( end );
			new Float:distance = GetVectorDistance( start, end, true );
			
			if(distance < 500){
				ForcePlayerSuicide(client);
			}
		}
	}
} 
//-------------------------------------------------------------------------------------------------
public bool:TraceFilter_All( entity, contentsMask ) {
	return false;
}
//-------------------------------------------------------------------------------------------------
stock FindDemoShield(iClient)
{
    new iEnt = MaxClients + 1; while ((iEnt = FindEntityByClassname2(iEnt, "tf_wearable_demoshield")) != -1)
    {
        if (GetEntPropEnt(iEnt, Prop_Send, "m_hOwnerEntity") == iClient && !GetEntProp(iEnt, Prop_Send, "m_bDisguiseWearable"))
        {
            return iEnt;
        }
    }
    return -1;
}
stock FindEntityByClassname2(startEnt, const String:classname[])
{
    /* If startEnt isn't valid shifting it back to the nearest valid one */
    while (startEnt > -1 && !IsValidEntity(startEnt)) startEnt--;
    return FindEntityByClassname(startEnt, classname);
}

