#if defined _weblink_included
	#endinput
#endif

#define _weblink_included

//-----------------------------------------------------------------------------
// Opens the specified link
//
native bool WEBLINK_OpenUrl( int client, const char[] link );

//-----------------------------------------------------------------------------
public SharedPlugin __pl_weblink = 
{
	name = "weblink",
	file = "weblink.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_weblink_SetNTVOptional()
{
	MarkNativeAsOptional("WEBLINK_OpenUrl");
}
#endif
