#if defined _rxgservices_included
	#endinput
#endif

#define _rxgservices_included

/** ---------------------------------------------------------------------------
 * Service response handler.
 *
 * @param error     If this is set, the request failed and data is an error
 *                  message. (stored the same as RT1)
 * @param response  Handle containing the response. The response type depends
 *                  on the command given. This handle should not be closed. 
 *                  This will be a DataPack containing one string if the 
 *                  request failed (error is true).
 * @param data      Arbitrary data passed by the caller.
 *
 *              For simple responses, the data is a plain string, or an 
 *              empty string if a non-RT1 response is received.
 *
 *              For normal responses, 
 *                RT1 is a DataPack with a single string.
 *                RT2 is a DataPack with multiple strings.
 *                RT3 is a KeyValues handle.
 *
 * @param rtype Type of response received. 
 *                0 = ERR, 1 = RT1, 2 = RT2, 3 = RT3
 */
funcenum RGS_Response {
	public( bool:error, Handle:response ),
	public( bool:error, Handle:response, any:data ),
	public( bool:error, Handle:response, any:data, rtype )
}
funcenum RGS_ResponseS {
	public( bool:error, const String:response[] ),
	public( bool:error, const String:response[], any:data )
}

/** ---------------------------------------------------------------------------
 * Make a request to the RXG services.
 *
 * @param handler Handler to call upon completion or INVALID_FUNCTION to
 *                ignore the response.
 * @param data    Data to pass to the callback.
 * @param message Message to send.
 * @param ...     Formatted arguments.
 */
native RGS_Request( RGS_Response:handler, any:data, 
					const String:message[], any:... );

/** ---------------------------------------------------------------------------
 * Make a simple request to the RXG services.
 *
 * This only allows retrieval of RT1 responses.
 *
 * @param handler Handler to call upon completion or INVALID_FUNCTION to
 *                ignore the response.
 * @param data    Data to pass to the callback.
 * @param message Message to send.
 * @param ...     Formatted arguments.
 */
native RGS_RequestS( RGS_ResponseS:handler, any:data, 
					 const String:message[], any:... );

/** ---------------------------------------------------------------------------
 * Check if the RXG services are available.
 *
 * @returns true if a connection is active.
 */
native bool:RGS_Connected();

/** ---------------------------------------------------------------------------
 * When a connection is made to the RXG service.
 */
forward RGS_OnConnected();

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
	MarkNativeAsOptional("RGS_Connected");
	MarkNativeAsOptional("RGS_Request");
	MarkNativeAsOptional("RGS_RequestS");
}
#endif