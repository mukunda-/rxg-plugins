#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <cstrike_weapons>

#pragma semicolon 1
#pragma newdecls required

//-----------------------------------------------------------------------------
public Plugin myinfo =  {
	name        = "dropgrenades",
	author      = "mukunda",
	description = "because they are hot",
	version     = "1.2.0",
	url         = "http://www.mukunda.com/"
};

Handle my_forward; 
bool   g_dropping_grenade;

//-----------------------------------------------------------------------------
public APLRes AskPluginLoad2( Handle myself, bool late, 
                              char[] error, int err_max ) {
	
	char gamedir[PLATFORM_MAX_PATH];
	GetGameFolderName( gamedir, sizeof gamedir );
	 
	RegPluginLibrary( "dropgrenade" );
	CreateNative( "DropGrenadeCheck", Native_Check );
	return APLRes_Success;
}

//-----------------------------------------------------------------------------
public void OnPluginStart() {
	my_forward = CreateGlobalForward( "OnPlayerDroppedGrenade", 
			ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
			
	AddCommandListener( OnDrop, "drop" );
}

//-----------------------------------------------------------------------------
public int Native_Check( Handle plugin, int args ) {
	return g_dropping_grenade;
}

//-----------------------------------------------------------------------------
public Action OnDrop( int client, const char[] command, int argc ) {
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" ) ) {	
		return Plugin_Continue;
	}
	
	int ent = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( ent <= 0 ) return Plugin_Continue;
	char name[32]; 
	
	GetEntityClassname( ent, name, sizeof name );
	WeaponType wt = GetWeaponType( name[7] );
	int ammo = GetEntProp( ent, Prop_Send, "m_iPrimaryAmmoType" );
	
	if( wt == WeaponTypeGrenade ) {
		CSWeaponID id = CS_AliasToWeaponID( name[7] );
		int amount = GetEntProp( client, Prop_Send, "m_iAmmo", _, ammo );
		// drop grenade
		
		g_dropping_grenade = true;
		CS_DropWeapon( client, ent, true, true );
		g_dropping_grenade = false;
		
		AcceptEntityInput( ent, "Kill" );
		SetEntProp( client, Prop_Send, "m_iAmmo", 0, _, ammo );
		PrintCenterText( client, "Discarded grenade." );
		
		Call_StartForward( my_forward );
		Call_PushCell( client );
		Call_PushCell( id );
		Call_PushCell( amount );
		Call_Finish();
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
} 
