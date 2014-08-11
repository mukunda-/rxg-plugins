#if defined _chickenthrowing_included
	#endinput
#endif

#define _chickenthrowing_included

//-------------------------------------------------------------------------------------------------
// Throw a chicken
//
// client: the client to throw from
// speed: speed of chicken
// gravity: gravity of chicken
//
native CHKN_ThrowChicken( client );

//-------------------------------------------------------------------------------------------------
public SharedPlugin:__pl_chickenthrowing = 
{
	name = "chickenthrowing",
	file = "chickenthrowing.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_chickenthrowing_SetNTVOptional()
{
	MarkNativeAsOptional("CHKN_ThrowChicken");
}
#endif
