#if defined _RXGUTILS_INCLUDED
 #endinput
#endif
#define _RXGUTILS_INCLUDED

forward RU_PlayerDeath( client, attacker );
forward RU_PlayerSpawn( client );
forward RU_RoundStart();

//-------------------------------------------------------------------------------------------------
public SharedPlugin:__pl_rxgutils = 
{
	name = "rxgutils",
	file = "rxgutils.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_rxgutils_SetNTVOptional()
{
	MarkNativeAsOptional("RU_PlayersAlive");
}
#endif
