#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <cstrike_weapons>

//-----------------------------------------------------------------------------
public Plugin:myinfo =  {
	name = "dropgrenades",
	author = "mukunda",
	description = "because they are hot",
	version = "1.0.1",
	url = "http://www.mukunda.com/"
};

new Handle:my_forward;

//-----------------------------------------------------------------------------
public OnPluginStart() {
	my_forward = CreateGlobalForward(
			"OnPlayerDroppedGrenade", 
			ET_Ignore, Param_Cell, Param_Cell, Param_Cell );
			
	AddCommandListener( OnDrop, "drop" );
}

//-----------------------------------------------------------------------------
public Action:OnDrop( client, const String:command[], argc ) {
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" ) ) {	
		return Plugin_Continue;
	}
	
	new ent = GetEntPropEnt( client, Prop_Send, "m_hActiveWeapon" );
	if( ent <= 0 ) return Plugin_Continue;
	decl String:name[64];
	name[63] = 0;
	
	GetEntityClassname( ent, name, sizeof name );
	new WeaponType:wt = GetWeaponType( name[7] );
	new ammo = GetEntProp( ent, Prop_Send, "m_iPrimaryAmmoType" );
	
	if( wt == WeaponTypeGrenade ) {
		new CSWeaponID:id = CS_AliasToWeaponID( name[7] );
		new amount = GetEntProp( client, Prop_Send, "m_iAmmo", _, ammo );
		// drop grenade
		CS_DropWeapon( client, ent, true, true );
		AcceptEntityInput( ent, "Kill" );
		SetEntProp( client, Prop_Send, "m_iAmmo", 0, _, ammo );
		PrintCenterText( client, "Discarded grenade." );
		
		Call_StartForward( my_forward );
		Call_PushCell( client );
		Call_PushCell( _:id );
		Call_PushCell( amount );
		Call_Finish();
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

//-----------------------------------------------------------------------------
