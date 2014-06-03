#if defined _aaawefwaefL_INCLUDED
 #endinput
#endif
#define _aaawefwaefL_INCLUDED

native Autoslay_ExplodePlayer(player);

public SharedPlugin:__pl_autoslay = 
{
	name = "autoslay",
	file = "autoslay.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_autoslay_SetNTVOptional()
{
	MarkNativeAsOptional("Autoslay_ExplodePlayer");
}
#endif
