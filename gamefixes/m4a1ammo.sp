/* /////////////////////////////////
// ______________  ___________ 
// \______   \   \/  /  _____/ 
//  |       _/\     /   \  ___ 
//  |    |   \/     \    \_\  \
//  |____|_  /___/\  \______  /
//         \/      \_/      \/
//     R E F L E X  -  G A M E R S
*/

#include <sourcemod>
#include <sdktools> 
#include <cstrike>
  
//-------------------------------------------------------------------------------------------------
public Plugin:myinfo =
{
	name = "M4A1AMMO",
	author = "mukunda/pray and spray",
	description = "Extra ammo for M4A1-S",
	version = "1.0.0",
	url = "www.reflex-gamers.com"
};

//-------------------------------------------------------------------------------------------------
#define ITEM_M4A1S 60
#define AMMO 60

//-------------------------------------------------------------------------------------------------
public OnPluginStart() {

	HookEvent( "item_purchase", OnItemPurchase );
	HookEvent( "enter_buyzone", OnEnterBuyzone ); 
	HookEvent( "weapon_reload", OnReloadWeapon ); 
}

//-------------------------------------------------------------------------------------------------
AdjustM4A1Ammo( client, weapon ) {
	// check if in buy-zone
	if( !GetEntProp( client, Prop_Send, "m_bInBuyZone" ) ) return;
	decl String:name[64];
	GetEntityClassname( weapon, name, sizeof name );
	if( !StrEqual( name, "weapon_m4a1" ) ) return; // not an M4x
	if( GetEntProp( weapon, Prop_Send, "m_iItemDefinitionIndex" ) != ITEM_M4A1S ) return; // not an M4A1-S
	
	// give additional ammo
	new ammotype = GetEntProp( weapon, Prop_Data, "m_iPrimaryAmmoType" );
	SetEntProp( client, Prop_Send, "m_iAmmo", AMMO, _, ammotype );
}

//-------------------------------------------------------------------------------------------------
AdjustPlayer( userid ) {
	new client = GetClientOfUserId( userid );
	if( client == 0 ) return; // user disconnected
	new weap = GetPlayerWeaponSlot( client, CS_SLOT_PRIMARY );
	if( weap == -1 ) return; // no primary weapon
	AdjustM4A1Ammo( client, weap );
}

//-------------------------------------------------------------------------------------------------
public Action:OnReloadDelayed( Handle:timer, any:userid ) {
	
	AdjustPlayer( userid );
	return Plugin_Handled;
}

//-------------------------------------------------------------------------------------------------
public OnReloadWeapon( Handle:event, const String:name[], bool:dontBroadcast ) {
	// if the user reloads, we add ammo if they are in the buy zone
	// we delay to let the reload finish first 
	new userid = GetEventInt( event, "userid" );
	CreateTimer( 2.0, OnReloadDelayed, userid, TIMER_FLAG_NO_MAPCHANGE );
}

//-------------------------------------------------------------------------------------------------
public OnEnterBuyzone( Handle:event, const String:name[], bool:dontBroadcast ) {
	// if the user enters the buy zone, replenish his ammo
	AdjustPlayer( GetEventInt( event, "userid" ) );
}

//-------------------------------------------------------------------------------------------------
public OnItemPurchase( Handle:event, const String:name[], bool:dontBroadcast ) {
	// adjust ammo when the user purchases an M4A1,
	// we don't know if it's an M4A1-S yet, which is checked later
	decl String:weapon[64];
	GetEventString( event, "weapon", weapon, sizeof weapon );
	if( strncmp( weapon, "m4a1", 4 ) != 0 ) return; // quick check to see if it's an m4a1 or m4a1_silencer
	AdjustPlayer( GetEventInt( event, "userid" ) );
}
