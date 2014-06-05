#if defined _rxgcompo_included
	#endinput
#endif

#define _rxgcompo_included
     
native COMPO_AddPoints( client, points,  const String:message[] );
native COMPO_GetTopPoints();
native COMPO_GetPoints( client );
 
public SharedPlugin:__pl_rxgstore = 
{
	name = "rxgcompo",
	file = "rxgcompo.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_rxgstore_SetNTVOptional()
{
	MarkNativeAsOptional("COMPO_AddPoints");
	MarkNativeAsOptional("COMPO_GetTopPoints");
	MarkNativeAsOptional("COMPO_GetPoints");
}
#endif
