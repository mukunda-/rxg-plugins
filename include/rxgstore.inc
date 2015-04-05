#if defined _rxgstore_included
	#endinput
#endif

#define _rxgstore_included
    
// todo: FORWARD OnItemRegistered/Unregistered

//-------------------------------------------------------------------------------------------------
// Register an item
// 
// name: name of item
// id: ITEMID
// fullname: user friendly full name of item
//
// returns true if item was registerd or false if all slots are in use
//
native RXGSTORE_RegisterItem( const String:name[], itemid, const String:fullname[] );

//-------------------------------------------------------------------------------------------------
// Unregister an item
//
// use when the plugin unloads.
//
native RXGSTORE_UnregisterItem( itemid );

//-------------------------------------------------------------------------------------------------
// Checks if the item is registered with the given item_id
//
native RXGSTORE_IsItemRegistered( itemid );

//-------------------------------------------------------------------------------------------------
// get how much item a client has
//
native RXGSTORE_ItemCount( client, itemid );

//-------------------------------------------------------------------------------------------------
// get how much cash a client has
//
// client: client index
//
// returns CENTS
//
native RXGSTORE_GetCash( client );

//-------------------------------------------------------------------------------------------------
// give cash to player
//
// amount in CENTS
//
native RXGSTORE_AddCash( client, amount );

//-------------------------------------------------------------------------------------------------
// take cash from client
//
// this is a threaded function that queries the DB and fires the callback when complete
// it also makes sure the cash is there before taking
//
// returns FALSE if invalid client specified
//
functag public TakeCashCB( userid, amount, any:data, bool:failed );
native bool:RXGSTORE_TakeCash( client, amount, TakeCashCB:callback, any:data=0 );

//-------------------------------------------------------------------------------------------------
// check if item count > 0
//
native RXGSTORE_CanUseItem( client, itemid );

//-------------------------------------------------------------------------------------------------
// delete 1 item from inventory
// 
native RXGSTORE_UseItem( client, itemid );

//-------------------------------------------------------------------------------------------------
// add an item to the client's inventory
//
native RXGSTORE_GiveItem( client, itemid, count = 1 );

//-------------------------------------------------------------------------------------------------
// show the useitem menu
// 
native RXGSTORE_ShowUseItemMenu( client );

//-------------------------------------------------------------------------------------------------
// check if client inventory has been loaded yet
//
native RXGSTORE_IsClientLoaded( client );

//-------------------------------------------------------------------------------------------------
// check if RXGSTORE has established a connection with the database
//
native bool:RXGSTORE_IsConnected();

// these functions are called from registered plugins:
// RXGSTORE_OnUse( client )

public SharedPlugin:__pl_rxgstore = 
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
	MarkNativeAsOptional("RXGSTORE_RegisterItem");
	MarkNativeAsOptional("RXGSTORE_UnregisterItem");
	MarkNativeAsOptional("RXGSTORE_ItemCount");
	MarkNativeAsOptional("RXGSTORE_GetCash");
	MarkNativeAsOptional("RXGSTORE_AddCash");
	MarkNativeAsOptional("RXGSTORE_TakeCash");
	MarkNativeAsOptional("RXGSTORE_CanUseItem");
	MarkNativeAsOptional("RXGSTORE_UseItem");
	MarkNativeAsOptional("RXGSTORE_ShowUseItemMenu");
	MarkNativeAsOptional("RXGSTORE_IsClientLoaded");
	MarkNativeAsOptional("RXGSTORE_IsConnected");
}
#endif
