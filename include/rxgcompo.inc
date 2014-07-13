#if defined _rxgcompo_included
	#endinput
#endif

#define _rxgcompo_included

enum {
	ADDPOINTS_ALWAYS = 1
};
     
native COMPO_AddPoints( client, points,  const String:message[], flags=0 );
native COMPO_GetTopPoints();
native COMPO_GetPoints( client );
native COMPO_GetRoundPlayers();
 
public SharedPlugin:__pl_rxgcompo = 
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
public __pl_rxgcompo_SetNTVOptional()
{
	MarkNativeAsOptional("COMPO_AddPoints");
	MarkNativeAsOptional("COMPO_GetTopPoints");
	MarkNativeAsOptional("COMPO_GetPoints");
	MarkNativeAsOptional("COMPO_GetRoundPlayers");
}
#endif
