
//-----------------------------------------------------------
#if defined TF2USE_INC
#endinput
#endif
#define TF2USE_INC

//-----------------------------------------------------------
// callback when entity is used
//
// client: player that touched entity
// entity: entity index
//
// return true to unhook entity
// return false to leave entity hooked
//
functag public bool:TF2Use_Callback( client, entity );

//-----------------------------------------------------------
// hook an entity so it can be used
// 
// callback: function that will be triggered when the
// user presses "E" on it (or "voicemenu 0 0")
//
native bool:TF2Use_Hook( entity, TF2Use_Callback:callback );  

//-----------------------------------------------------------
// unhook an entity
//
native bool:TF2Use_Unhook( entity );

//-----------------------------------------------------------
public SharedPlugin:__pl_tf2use = 
{
	name = "tf2use",
	file = "tf2use.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

//-----------------------------------------------------------
#if !defined REQUIRE_PLUGIN
public __pl_tf2use_SetNTVOptional()
{
	MarkNativeAsOptional("TF2Use_Hook");
	MarkNativeAsOptional("TF2Use_Unhook");
}
#endif
//-----------------------------------------------------------
