#if defined _monoculus_included
	#endinput
#endif

#define _monoculus_included

//-------------------------------------------------------------------------------------------------
// Spawn a Monoculus
//
// client: the client to spawn from
// team: the team index to spawn the monoculus as
//
native MONO_SpawnMonoculus( client, team );

//-------------------------------------------------------------------------------------------------
public SharedPlugin:__pl_monoculus = 
{
	name = "monoculus",
	file = "monoculus.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_monoculus_SetNTVOptional()
{
	MarkNativeAsOptional("MONO_SpawnMonoculus");
}
#endif
