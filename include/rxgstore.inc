#if defined _rxgstore_included
	#endinput
#endif

#define _rxgstore_included
    
// todo: FORWARD OnItemRegistered/Unregistered

/** ---------------------------------------------------------------------------
 * Register an item.
 *
 * Plugins that call this must provide a function with the prototype
 *
 *   bool RXGSTORE_OnUse( int client )
 *
 * for when the item is being used by the client. Return true to delete
 * one of the item in the clients inventory, or false if the client cannot
 * use the item at that time.
 *
 * @param name     Name of item. (internal name, eg "cookie")
 * @param itemid   Store item ID.
 * @param fullname User friendly name of item.
 *
 * @returns true if item was registered or false if all slots are in use.
 */
native bool RXGSTORE_RegisterItem( const char[] name, int itemid, 
                                   const char[] fullname );

/** ---------------------------------------------------------------------------
 * Unregister an item.
 *
 * This should be called when an item plugin unloads.
 */
native void RXGSTORE_UnregisterItem( int itemid );

/** ---------------------------------------------------------------------------
 * Checks if an item id is currently registered.
 */
native bool RXGSTORE_IsItemRegistered( int itemid );

/** ---------------------------------------------------------------------------
 * Get how much of an item a client has.
 *
 * @param client Client to check.
 * @param itemid Item ID to count.
 */
native RXGSTORE_ItemCount( int client, int itemid );

/** ---------------------------------------------------------------------------
 * Get how much cash a client has.
 *
 * @param client Client index.
 * @returns Amount of rxg dollars.
 */
native RXGSTORE_GetCash( int client );

/** ---------------------------------------------------------------------------
 * Give cash to player.
 *
 * @param client Client to give cash to.
 * @param amount Amount of rxg dollars to give them.
 */
native RXGSTORE_AddCash( int client, int amount );

/** ---------------------------------------------------------------------------
 * Callback prototype for taking cash from a player.
 *
 * @param userid The userid of the player that the cash was taken from.
 * @param amount The number of rxg dollars that was lost.
 * @param data   Optional data from the caller.
 * @param failed True if the cash was unable to be removed 
 *               (insufficient funds or database error).
 */
typedef TakeCashCB = function void ( int userid, int amount, any data, 
                                     bool failed );

/** ---------------------------------------------------------------------------
 * Take cash from client.
 *
 * This is a threaded function that queries the database and fires the
 * callback when the operation completes. It also makes sure the cash is
 * there before taking it.
 *
 * @param client   Client to remove cash from.
 * @param amount   Amount of rxg dollars to take.
 * @param callback Function that will be triggered after the cash is removed.
 * @param data     Optional data to pass to the callback.
 *
 * @returns false if an invalid client was specified.
 */
native bool RXGSTORE_TakeCash( int client, int amount, TakeCashCB callback, 
                               any data = 0 );

/** ---------------------------------------------------------------------------
 * Check if a client has at least 1 of the specified item.
 * 
 * @param client Client to check.
 * @param itemid ID of the item.
 *
 * @returns true if the client can use the item.
 */
native bool RXGSTORE_CanUseItem( int client, int itemid );

/** ---------------------------------------------------------------------------
 * Delete 1 of an item from a client's inventory.
 * 
 * @param client Client index.
 * @param itemid ID of item to use.
 *
 * @returns true if an item was deleted, false if the client doesn't have
 *               the item or the operation otherwise failed.
 */
native bool RXGSTORE_UseItem( int client, int itemid );

/** ---------------------------------------------------------------------------
 * Add an item to the client's inventory.
 *
 * @param client Client index.
 * @param itemid ID of item to give.
 * @param count  Quantity of the item to give.
 *
 * @returns true on success, false on failure.
 */
native bool RXGSTORE_GiveItem( int client, int itemid, int count = 1 );

/** ---------------------------------------------------------------------------
 * Show the "Use Item" menu to a client.
 *
 * @param client Client index.
 */
native RXGSTORE_ShowUseItemMenu( int client );

/** ---------------------------------------------------------------------------
 * Check if a client's inventory has been loaded yet.
 *
 * Client inventories are loaded periodically or after each round ends, and
 * may not be loaded immediately after a client joins.
 *
 * @param client Client index.
 * @returns true if the client's inventory is loaded/cached.
 */
native bool RXGSTORE_IsClientLoaded( int client );

/** ---------------------------------------------------------------------------
 * Check if the rxgstore plugin has established a connection with 
 * the database.
 */
native bool RXGSTORE_IsConnected();
 
//-----------------------------------------------------------------------------
public SharedPlugin __pl_rxgstore = 
{
	name = "rxgstore",
	file = "rxgstore.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_rxgstore_SetNTVOptional()
{
	MarkNativeAsOptional( "RXGSTORE_RegisterItem"    );
	MarkNativeAsOptional( "RXGSTORE_UnregisterItem"  );
	MarkNativeAsOptional( "RXGSTORE_ItemCount"       );
	MarkNativeAsOptional( "RXGSTORE_GetCash"         );
	MarkNativeAsOptional( "RXGSTORE_AddCash"         );
	MarkNativeAsOptional( "RXGSTORE_TakeCash"        );
	MarkNativeAsOptional( "RXGSTORE_CanUseItem"      );
	MarkNativeAsOptional( "RXGSTORE_UseItem"         );
	MarkNativeAsOptional( "RXGSTORE_ShowUseItemMenu" );
	MarkNativeAsOptional( "RXGSTORE_IsClientLoaded"  );
	MarkNativeAsOptional( "RXGSTORE_IsConnected"     );
}
#endif
