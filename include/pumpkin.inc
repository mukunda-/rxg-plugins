#if defined _pumpkin_included
	#endinput
#endif

#define _pumpkin_included

//-------------------------------------------------------------------------------------------------
// Spawn a Pumpkin at aim
//
// client: the client to spawn from
// maxDistance: max distance it will spawn from player
// maxPumpkins: max pumpkins a player can have spawned
native PMKN_SpawnPumpkinAtAim( int client, float maxDistance, int maxPumpkins );

//-------------------------------------------------------------------------------------------------
public SharedPlugin __pl_pumpkin = 
{
	name = "pumpkin",
	file = "pumpkin.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_pumpkin_SetNTVOptional()
{
	MarkNativeAsOptional("PMKN_SpawnPumpkinAtAim");
}
#endif
