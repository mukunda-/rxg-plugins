#if defined _rxgservices_included
	#endinput
#endif

#define _rxgservices_included

/** ---------------------------------------------------------------------------
 * Service response handler.
 *
 * @param data Handle containing the response. The response type depends
 *             on the command given. This handle should not be closed. 
 *             May be INVALID_HANDLE if the request failed.
 */
functag public RGS_Response( Handle:data );

/** ---------------------------------------------------------------------------
 * Make a request to the RXG services.
 *
 * @param handler Handler to call upon completion.
 * @param message Message to send.
 * @param ...     Formatted arguments.
 */
native RGS_Request( RGS_Response:handler, const String:message[], any:... );

/** ---------------------------------------------------------------------------
 * Check if the RXG services are available.
 *
 * @returns true if a connection is active.
 */
native bool:RGS_Connected();
 
//-----------------------------------------------------------------------------
public SharedPlugin:__pl_rxgservices = 
{
	name = "rxgservices",
	file = "rxgservices.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_rxgservices_SetNTVOptional()
{
	//MarkNativeAsOptional("...");
}
#endif