#if defined _DROPGRENADEINCLUDED
 #endinput
#endif
#define _DROPGRENADEINCLUDED

/** ---------------------------------------------------------------------------
 * If called inside of a WeaponDrop hook, returns true if the WeaponDrop
 * was caused by discarding a grenade.
 */
native bool:DropGrenadeCheck();

/** ---------------------------------------------------------------------------
 * Called after a grenade is discarded.
 */
forward OnPlayerDroppedGrenade( client, CSWeaponID:id, amount );

//-----------------------------------------------------------------------------
public SharedPlugin:__pl_dropgrenade = 
{
	name = "dropgrenade",
	file = "dropgrenade.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

//-----------------------------------------------------------------------------
#if !defined REQUIRE_PLUGIN
public __pl_dropgrenade_SetNTVOptional()
{
	MarkNativeAsOptional("DropGrenade_Check");
}
#endif
