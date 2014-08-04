#if defined _storeweapons_included
	#endinput
#endif

#define _storeweapons_included

//-------------------------------------------------------------------------------------------------
// Give a Store Weapon to a client
//
// client: the client to give the weapon to
// weapon_index: the entity index of the weapon
// weapon_name: name of weapon to broadcast in chat
// weapon_text_color: color of weapon for chat broadcast
//
native STOREWEAPONS_GiveWeapon( client, weapon_index, TFClassType:class_restriction, String:weapon_name[], String:weapon_text_color[] );

//-------------------------------------------------------------------------------------------------
public SharedPlugin:__pl_storeweapons = 
{
	name = "storeweapons",
	file = "storeweapons.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_storeweapons_SetNTVOptional()
{
	MarkNativeAsOptional("STOREWEAPONS_GiveWeapon");
}
#endif
