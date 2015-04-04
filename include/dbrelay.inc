#if defined _dbrelay_included
	#endinput
#endif

#define _dbrelay_included

//-----------------------------------------------------------------------------
// Global forward that fires when the database relay establishes a connection. This will also fire
// on a reconnect after dropping the connection.
//
forward OnDBRelayConnected();

//-----------------------------------------------------------------------------
// Checks if the Database is connected and returns true/false
//
native bool DBRELAY_IsConnected();

//-----------------------------------------------------------------------------
// Runs a threaded query through the Database Relay
// 
// callback: the callback for when the query has completed
// query: the query string
// data: data to pass to the callback
// prio: priority of query
// 
native DBRELAY_TQuery( SQLTCallback callback, const char[] query, any data = 0, DBPriority prio = DBPrio_Normal );

//-----------------------------------------------------------------------------
public SharedPlugin __pl_dbrelay = 
{
	name = "dbrelay",
	file = "dbrelay.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_dbrelay_SetNTVOptional()
{
	MarkNativeAsOptional("DBRELAY_IsConnected");
	MarkNativeAsOptional("DBRELAY_TQuery");
}
#endif
