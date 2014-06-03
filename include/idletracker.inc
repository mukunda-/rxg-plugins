#if defined _IDLETRACKER_INCLUDED
 #endinput
#endif
#define _IDLETRACKER_INCLUDED

// returns how long a client has been idle
//
native Float:GetClientIdleTime(client);

// returns true if client hasn't moved from spawn
//
native bool:IsClientIdleAtSpawn(client);

