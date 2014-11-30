#if defined _DONATIONS_INCLUDED
 #endinput
#endif
#define _DONATIONS_INCLUDED

//-----------------------------------------------------------------------------
// Get donator level for client.
// 
// @param client Client index.
// @returns 1 if they have perks, 0 if they don't have perks or they have
//          not been cached yet.
//
native Donations_GetClientLevel(client);

//-----------------------------------------------------------------------------
// Check if a client has $5/mo perks.
//
native bool:Donations_Perks5( client );

//-----------------------------------------------------------------------------
// Check if a client has $1/mo perks.
//
native bool:Donations_Perks1( client );

//-----------------------------------------------------------------------------
// Get donator level for client and ignore admin status.
// (admins always have 1 for GetClientLevel)
//
native Donations_GetClientLevelDirect(client);

//-----------------------------------------------------------------------------
// Check if a client's donation information is cached.
//
native Donations_IsClientCached(client);

//-----------------------------------------------------------------------------
// Called when a client has loaded or reloaded his donation status
//
// @param client Client index.
// @param onjoin `true` if this is the first verification for a client during 
//               his session, and not when a client uses /verify
//
forward Donations_OnClientCached( client, bool:onjoin );

//-----------------------------------------------------------------------------
// Actions passed to a VIP menu handler.
//
enum VIPAction{
	VIP_ACTION_USE = 1, // client is a donator and wants to use this feature
	VIP_ACTION_HELP = 2, // client is not a donator and handler should print information only
};

//-----------------------------------------------------------------------------
// Interface for VIP plugins.
//
functag VIPHandler public( client, VIPAction:action );

//-----------------------------------------------------------------------------
// Register a VIP item.
//
// @param name    Option name that will show up in the !vip menu.
// @param handler Handler to call when they select a VIP item.
//
native VIP_Register( const String:name[], VIPHandler:handler );

//-----------------------------------------------------------------------------
// Unregister a VIP item.
//
// This unregisters any VIP items registered with the calling plugin.
//
native VIP_Unregister();

