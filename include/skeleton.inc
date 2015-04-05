#if defined _skeleton_included
	#endinput
#endif

#define _skeleton_included

//-------------------------------------------------------------------------------------------------
// Spawn a Skeleton
//
// client: the client to spawn from
// team: the team index to spawn the skeleton as
//
native SKEL_SpawnSkeleton( client, team );

//-------------------------------------------------------------------------------------------------
public SharedPlugin __pl_skeleton = 
{
	name = "skeleton",
	file = "skeleton.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_skeleton_SetNTVOptional()
{
	MarkNativeAsOptional("SKEL_SpawnSkeleton");
}
#endif
