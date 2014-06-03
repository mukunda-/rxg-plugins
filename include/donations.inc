#if defined _DONATIONS_INCLUDED
 #endinput
#endif
#define _DONATIONS_INCLUDED

// get donator level
// returns 0 if data is not cached yet
//
native Donations_GetClientLevel(client);
native Donations_GetClientLevelDirect(client); // exclude admins and whitelist

// returns true if client has donation data loaded
// false if the query is still pending or an error occurred
//
native Donations_IsClientCached(client);

// called when a client has loaded (or reloaded!) his donation status
// onjoin is true if this is the first verification for a client during his session
//   (and not when a client uses /verify)
//
forward Donations_OnClientCached( client, bool:onjoin );

enum VIPAction{
	VIP_ACTION_USE = 1, // client is a donator and wants to use this feature
	VIP_ACTION_HELP = 2, // client is not a donator and handler should print information only
} ;

functag VIPHandler public( client, VIPAction:action );

native VIP_Register( const String:name[], VIPHandler:handler );
native VIP_Unregister();

