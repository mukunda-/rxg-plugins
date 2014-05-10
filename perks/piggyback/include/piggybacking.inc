
#if defined PIGGY_INC
#endinput
#endif
#define PIGGY_INC

// return Plugin_handled to disallow piggybacking
//
forward Action:Piggybacking_OnUse( client );

native bool:IsClientPiggybacking( client );

public SharedPlugin:__pl_piggyback = 
{
	name = "piggyback",
	file = "piggyback.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_piggyback_SetNTVOptional()
{
	MarkNativeAsOptional("Piggybacking_OnUse");
	MarkNativeAsOptional("IsClientPiggybacking");
}
#endif
