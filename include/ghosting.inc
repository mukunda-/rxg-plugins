
#if defined GHOSTING_INC
#endinput
#endif
#define GHOSTING_INC

// called when a ghost is about to try and process a command fired from OnPlayerRunCmd
// return Plugin_Handled to block commands from there (for button input overrides)
// return Plugin_Continue for normal behavior
//
forward Action:Ghosting_OnAllowCmd( client );

// called when a ghost triggers +use on an entity
//
// return Plugin_Handled if you handled the operation, or Plugin_Continue to allow other mods to process the use

// this function is only called when player is dead/spectating and in free roaming mode
forward Action:Ghosting_OnUse( client, entity );
